const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const compression = require('compression');
const morgan = require('morgan');
const prometheus = require('prom-client');
const { Pool } = require('pg');
const Redis = require('ioredis');
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const app = express();
const PORT = process.env.PORT || 3000;

// Prometheus metrics
const collectDefaultMetrics = prometheus.collectDefaultMetrics;
collectDefaultMetrics({ register: prometheus.register });

// Custom metrics
const httpRequestDurationMicroseconds = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

const httpRequestsTotal = new prometheus.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const activeConnections = new prometheus.Gauge({
  name: 'active_connections',
  help: 'Number of active connections'
});

const orderSuccessRate = new prometheus.Gauge({
  name: 'order_success_rate',
  help: 'Order success rate percentage'
});

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:password@localhost:5432/zomato',
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// Redis connection
const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

// Swagger configuration
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Zomato Clone API',
      version: '1.0.0',
      description: 'Advanced Zomato clone with OpenKruise integration',
    },
    servers: [
      {
        url: `http://localhost:${PORT}`,
        description: 'Development server',
      },
    ],
  },
  apis: ['./src/*.js'],
};

const specs = swaggerJsdoc(swaggerOptions);

// Middleware
app.use(helmet());
app.use(compression());
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Logging
app.use(morgan('combined'));

// Swagger documentation
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(specs));

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    // Check database connection
    await pool.query('SELECT 1');
    
    // Check Redis connection
    await redis.ping();
    
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      database: 'connected',
      redis: 'connected'
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message
    });
  }
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', prometheus.register.contentType);
    res.end(await prometheus.register.metrics());
  } catch (error) {
    res.status(500).end(error);
  }
});

// Middleware to track metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    httpRequestDurationMicroseconds
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .observe(duration / 1000);
    
    httpRequestsTotal
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .inc();
  });
  
  next();
});

// Database initialization
async function initializeDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS restaurants (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        cuisine VARCHAR(100),
        rating DECIMAL(3,2),
        delivery_time INTEGER,
        min_order DECIMAL(10,2),
        address TEXT,
        phone VARCHAR(20),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS menu_items (
        id SERIAL PRIMARY KEY,
        restaurant_id INTEGER REFERENCES restaurants(id),
        name VARCHAR(255) NOT NULL,
        description TEXT,
        price DECIMAL(10,2) NOT NULL,
        category VARCHAR(100),
        is_vegetarian BOOLEAN DEFAULT false,
        is_available BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS orders (
        id SERIAL PRIMARY KEY,
        user_id INTEGER,
        restaurant_id INTEGER REFERENCES restaurants(id),
        total_amount DECIMAL(10,2) NOT NULL,
        status VARCHAR(50) DEFAULT 'pending',
        delivery_address TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS order_items (
        id SERIAL PRIMARY KEY,
        order_id INTEGER REFERENCES orders(id),
        menu_item_id INTEGER REFERENCES menu_items(id),
        quantity INTEGER NOT NULL,
        price DECIMAL(10,2) NOT NULL,
        special_instructions TEXT
      )
    `);

    console.log('Database initialized successfully');
  } catch (error) {
    console.error('Database initialization error:', error);
  }
}

// Sample data insertion
async function insertSampleData() {
  try {
    // Check if data already exists
    const restaurantCount = await pool.query('SELECT COUNT(*) FROM restaurants');
    if (parseInt(restaurantCount.rows[0].count) > 0) {
      return;
    }

    // Insert sample restaurants
    const restaurant1 = await pool.query(`
      INSERT INTO restaurants (name, cuisine, rating, delivery_time, min_order, address, phone)
      VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id
    `, ['Spice Garden', 'Indian', 4.5, 30, 15.00, '123 Main St, Downtown', '+1-555-0101']);

    const restaurant2 = await pool.query(`
      INSERT INTO restaurants (name, cuisine, rating, delivery_time, min_order, address, phone)
      VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id
    `, ['Pizza Palace', 'Italian', 4.2, 25, 20.00, '456 Oak Ave, Midtown', '+1-555-0102']);

    // Insert sample menu items
    await pool.query(`
      INSERT INTO menu_items (restaurant_id, name, description, price, category, is_vegetarian)
      VALUES 
        ($1, $2, $3, $4, $5, $6),
        ($1, $7, $8, $9, $10, $11)
    `, [
      restaurant1.rows[0].id, 'Butter Chicken', 'Creamy tomato-based curry with tender chicken', 18.99, 'Main Course', false,
      restaurant1.rows[0].id, 'Paneer Tikka', 'Grilled cottage cheese with Indian spices', 16.99, 'Appetizer', true
    ]);

    await pool.query(`
      INSERT INTO menu_items (restaurant_id, name, description, price, category, is_vegetarian)
      VALUES 
        ($1, $2, $3, $4, $5, $6),
        ($1, $7, $8, $9, $10, $11)
    `, [
      restaurant2.rows[0].id, 'Margherita Pizza', 'Classic tomato and mozzarella pizza', 22.99, 'Pizza', true,
      restaurant2.rows[0].id, 'Chicken Alfredo', 'Creamy pasta with grilled chicken', 24.99, 'Pasta', false
    ]);

    console.log('Sample data inserted successfully');
  } catch (error) {
    console.error('Sample data insertion error:', error);
  }
}

// API Routes

/**
 * @swagger
 * /api/restaurants:
 *   get:
 *     summary: Get all restaurants
 *     tags: [Restaurants]
 *     responses:
 *       200:
 *         description: List of restaurants
 */
app.get('/api/restaurants', async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM restaurants ORDER BY rating DESC');
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * @swagger
 * /api/restaurants/{id}:
 *   get:
 *     summary: Get restaurant by ID
 *     tags: [Restaurants]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Restaurant details
 */
app.get('/api/restaurants/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await pool.query(`
      SELECT r.*, 
             json_agg(json_build_object('id', mi.id, 'name', mi.name, 'description', mi.description, 'price', mi.price, 'category', mi.category, 'is_vegetarian', mi.is_vegetarian)) as menu
      FROM restaurants r
      LEFT JOIN menu_items mi ON r.id = mi.restaurant_id
      WHERE r.id = $1
      GROUP BY r.id
    `, [id]);
    
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Restaurant not found' });
    }
    
    res.json(rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * @swagger
 * /api/orders:
 *   post:
 *     summary: Create a new order
 *     tags: [Orders]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               user_id:
 *                 type: integer
 *               restaurant_id:
 *                 type: integer
 *               items:
 *                 type: array
 *               delivery_address:
 *                 type: string
 *     responses:
 *       201:
 *         description: Order created successfully
 */
app.post('/api/orders', async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    const { user_id, restaurant_id, items, delivery_address } = req.body;
    
    // Calculate total amount
    let total_amount = 0;
    for (const item of items) {
      const { rows } = await client.query('SELECT price FROM menu_items WHERE id = $1', [item.menu_item_id]);
      if (rows.length === 0) {
        throw new Error(`Menu item ${item.menu_item_id} not found`);
      }
      total_amount += rows[0].price * item.quantity;
    }
    
    // Create order
    const orderResult = await client.query(`
      INSERT INTO orders (user_id, restaurant_id, total_amount, delivery_address)
      VALUES ($1, $2, $3, $4) RETURNING id
    `, [user_id, restaurant_id, total_amount, delivery_address]);
    
    const orderId = orderResult.rows[0].id;
    
    // Create order items
    for (const item of items) {
      const { rows } = await client.query('SELECT price FROM menu_items WHERE id = $1', [item.menu_item_id]);
      await client.query(`
        INSERT INTO order_items (order_id, menu_item_id, quantity, price, special_instructions)
        VALUES ($1, $2, $3, $4, $5)
      `, [orderId, item.menu_item_id, item.quantity, rows[0].price, item.special_instructions]);
    }
    
    await client.query('COMMIT');
    
    // Update metrics
    orderSuccessRate.set(100); // Assuming successful order creation
    
    res.status(201).json({
      message: 'Order created successfully',
      order_id: orderId,
      total_amount: total_amount
    });
  } catch (error) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: error.message });
  } finally {
    client.release();
  }
});

/**
 * @swagger
 * /api/orders/{id}:
 *   get:
 *     summary: Get order by ID
 *     tags: [Orders]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Order details
 */
app.get('/api/orders/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await pool.query(`
      SELECT o.*, 
             json_agg(json_build_object('id', oi.id, 'menu_item_id', oi.menu_item_id, 'quantity', oi.quantity, 'price', oi.price, 'special_instructions', oi.special_instructions)) as items
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      WHERE o.id = $1
      GROUP BY o.id
    `, [id]);
    
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }
    
    res.json(rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Search functionality
app.get('/api/search', async (req, res) => {
  try {
    const { q, cuisine, min_rating, max_price } = req.query;
    
    let query = 'SELECT * FROM restaurants WHERE 1=1';
    const params = [];
    let paramCount = 0;
    
    if (q) {
      paramCount++;
      query += ` AND (name ILIKE $${paramCount} OR address ILIKE $${paramCount})`;
      params.push(`%${q}%`);
    }
    
    if (cuisine) {
      paramCount++;
      query += ` AND cuisine ILIKE $${paramCount}`;
      params.push(`%${cuisine}%`);
    }
    
    if (min_rating) {
      paramCount++;
      query += ` AND rating >= $${paramCount}`;
      params.push(parseFloat(min_rating));
    }
    
    if (max_price) {
      paramCount++;
      query += ` AND min_order <= $${paramCount}`;
      params.push(parseFloat(max_price));
    }
    
    query += ' ORDER BY rating DESC';
    
    const { rows } = await pool.query(query, params);
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Cache middleware for Redis
const cache = (duration) => {
  return async (req, res, next) => {
    const key = `cache:${req.originalUrl}`;
    
    try {
      const cached = await redis.get(key);
      if (cached) {
        return res.json(JSON.parse(cached));
      }
      
      res.sendResponse = res.json;
      res.json = (body) => {
        redis.setex(key, duration, JSON.stringify(body));
        res.sendResponse(body);
      };
      
      next();
    } catch (error) {
      next();
    }
  };
};

// Apply cache to read-only endpoints
app.get('/api/restaurants', cache(300), async (req, res) => {
  // ... existing code
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error(error.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  await pool.end();
  await redis.quit();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully');
  await pool.end();
  await redis.quit();
  process.exit(0);
});

// Start server
async function startServer() {
  try {
    await initializeDatabase();
    await insertSampleData();
    
    app.listen(PORT, () => {
      console.log(`🚀 Zomato Clone API server running on port ${PORT}`);
      console.log(`📊 Metrics available at http://localhost:${PORT}/metrics`);
      console.log(`📚 API documentation at http://localhost:${PORT}/api-docs`);
      console.log(`🏥 Health check at http://localhost:${PORT}/health`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();

module.exports = app;
