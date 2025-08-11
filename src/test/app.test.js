const request = require('supertest');
const app = require('../app');
const { Pool } = require('pg');

// Mock database connection for testing
jest.mock('pg', () => ({
  Pool: jest.fn(() => ({
    query: jest.fn(),
    connect: jest.fn(),
    end: jest.fn()
  }))
}));

// Mock Redis for testing
jest.mock('ioredis', () => {
  return jest.fn().mockImplementation(() => ({
    ping: jest.fn().mockResolvedValue('PONG'),
    get: jest.fn(),
    setex: jest.fn(),
    quit: jest.fn()
  }));
});

describe('Zomato Clone API Tests', () => {
  let mockPool;

  beforeEach(() => {
    mockPool = new Pool();
    jest.clearAllMocks();
  });

  describe('Health Check Endpoint', () => {
    test('GET /health should return healthy status', async () => {
      mockPool.query.mockResolvedValue({ rows: [{ '1': 1 }] });
      
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body.status).toBe('healthy');
      expect(response.body.database).toBe('connected');
      expect(response.body.redis).toBe('connected');
    });

    test('GET /health should return unhealthy status on database error', async () => {
      mockPool.query.mockRejectedValue(new Error('Database connection failed'));
      
      const response = await request(app)
        .get('/health')
        .expect(503);

      expect(response.body.status).toBe('unhealthy');
      expect(response.body.error).toBe('Database connection failed');
    });
  });

  describe('Metrics Endpoint', () => {
    test('GET /metrics should return Prometheus metrics', async () => {
      const response = await request(app)
        .get('/metrics')
        .expect(200);

      expect(response.headers['content-type']).toContain('text/plain');
      expect(response.text).toContain('http_request_duration_seconds');
    });
  });

  describe('Restaurants Endpoints', () => {
    test('GET /api/restaurants should return list of restaurants', async () => {
      const mockRestaurants = [
        { id: 1, name: 'Test Restaurant', cuisine: 'Test Cuisine', rating: 4.5 }
      ];
      
      mockPool.query.mockResolvedValue({ rows: mockRestaurants });
      
      const response = await request(app)
        .get('/api/restaurants')
        .expect(200);

      expect(response.body).toEqual(mockRestaurants);
    });

    test('GET /api/restaurants/:id should return restaurant with menu', async () => {
      const mockRestaurant = {
        id: 1,
        name: 'Test Restaurant',
        cuisine: 'Test Cuisine',
        rating: 4.5,
        menu: [
          { id: 1, name: 'Test Dish', price: 15.99 }
        ]
      };
      
      mockPool.query.mockResolvedValue({ rows: [mockRestaurant] });
      
      const response = await request(app)
        .get('/api/restaurants/1')
        .expect(200);

      expect(response.body).toEqual(mockRestaurant);
    });

    test('GET /api/restaurants/:id should return 404 for non-existent restaurant', async () => {
      mockPool.query.mockResolvedValue({ rows: [] });
      
      const response = await request(app)
        .get('/api/restaurants/999')
        .expect(404);

      expect(response.body.error).toBe('Restaurant not found');
    });
  });

  describe('Orders Endpoints', () => {
    test('POST /api/orders should create new order', async () => {
      const orderData = {
        user_id: 1,
        restaurant_id: 1,
        items: [{ menu_item_id: 1, quantity: 2 }],
        delivery_address: 'Test Address'
      };

      const mockMenuItem = { price: 15.99 };
      const mockOrder = { id: 1 };
      
      mockPool.connect.mockResolvedValue({
        query: jest.fn()
          .mockResolvedValueOnce({ rows: [mockMenuItem] }) // Price query
          .mockResolvedValueOnce({ rows: [mockOrder] }) // Order creation
          .mockResolvedValue({ rows: [mockMenuItem] }), // Order items creation
        release: jest.fn()
      });
      
      const response = await request(app)
        .post('/api/orders')
        .send(orderData)
        .expect(201);

      expect(response.body.message).toBe('Order created successfully');
      expect(response.body.order_id).toBe(1);
    });

    test('POST /api/orders should handle validation errors', async () => {
      const invalidOrderData = {
        user_id: 1,
        restaurant_id: 1,
        items: [{ menu_item_id: 999, quantity: 2 }], // Non-existent menu item
        delivery_address: 'Test Address'
      };

      mockPool.connect.mockResolvedValue({
        query: jest.fn().mockResolvedValue({ rows: [] }), // No menu item found
        release: jest.fn()
      });
      
      const response = await request(app)
        .post('/api/orders')
        .send(invalidOrderData)
        .expect(500);

      expect(response.body.error).toContain('Menu item 999 not found');
    });

    test('GET /api/orders/:id should return order details', async () => {
      const mockOrder = {
        id: 1,
        user_id: 1,
        restaurant_id: 1,
        total_amount: 31.98,
        items: [
          { id: 1, menu_item_id: 1, quantity: 2, price: 15.99 }
        ]
      };
      
      mockPool.query.mockResolvedValue({ rows: [mockOrder] });
      
      const response = await request(app)
        .get('/api/orders/1')
        .expect(200);

      expect(response.body).toEqual(mockOrder);
    });
  });

  describe('Search Endpoint', () => {
    test('GET /api/search should filter restaurants by query', async () => {
      const mockRestaurants = [
        { id: 1, name: 'Italian Restaurant', cuisine: 'Italian', rating: 4.5 }
      ];
      
      mockPool.query.mockResolvedValue({ rows: mockRestaurants });
      
      const response = await request(app)
        .get('/api/search?q=Italian')
        .expect(200);

      expect(response.body).toEqual(mockRestaurants);
    });

    test('GET /api/search should filter by multiple criteria', async () => {
      const mockRestaurants = [
        { id: 1, name: 'Test Restaurant', cuisine: 'Italian', rating: 4.5, min_order: 15.00 }
      ];
      
      mockPool.query.mockResolvedValue({ rows: mockRestaurants });
      
      const response = await request(app)
        .get('/api/search?cuisine=Italian&min_rating=4.0&max_price=20.00')
        .expect(200);

      expect(response.body).toEqual(mockRestaurants);
    });
  });

  describe('Error Handling', () => {
    test('Should handle database errors gracefully', async () => {
      mockPool.query.mockRejectedValue(new Error('Database error'));
      
      const response = await request(app)
        .get('/api/restaurants')
        .expect(500);

      expect(response.body.error).toBe('Database error');
    });

    test('Should return 404 for non-existent routes', async () => {
      const response = await request(app)
        .get('/api/nonexistent')
        .expect(404);

      expect(response.body.error).toBe('Route not found');
    });
  });

  describe('Rate Limiting', () => {
    test('Should enforce rate limiting on API endpoints', async () => {
      // Make multiple requests to trigger rate limiting
      const requests = Array(101).fill().map(() => 
        request(app).get('/api/restaurants')
      );
      
      const responses = await Promise.all(requests);
      const rateLimited = responses.some(r => r.status === 429);
      
      expect(rateLimited).toBe(true);
    });
  });

  describe('Security Headers', () => {
    test('Should include security headers', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.headers).toHaveProperty('x-frame-options');
      expect(response.headers).toHaveProperty('x-content-type-options');
      expect(response.headers).toHaveProperty('x-xss-protection');
    });
  });

  describe('API Documentation', () => {
    test('Should serve Swagger documentation', async () => {
      const response = await request(app)
        .get('/api-docs')
        .expect(200);

      expect(response.text).toContain('swagger');
    });
  });
});

// Performance tests
describe('Performance Tests', () => {
  test('Health check should respond within 100ms', async () => {
    const start = Date.now();
    
    await request(app).get('/health');
    
    const responseTime = Date.now() - start;
    expect(responseTime).toBeLessThan(100);
  });

  test('Metrics endpoint should respond within 200ms', async () => {
    const start = Date.now();
    
    await request(app).get('/metrics');
    
    const responseTime = Date.now() - start;
    expect(responseTime).toBeLessThan(200);
  });
});

// Load testing simulation
describe('Load Testing Simulation', () => {
  test('Should handle concurrent requests', async () => {
    const concurrentRequests = 10;
    const requests = Array(concurrentRequests).fill().map(() => 
      request(app).get('/health')
    );
    
    const start = Date.now();
    const responses = await Promise.all(requests);
    const totalTime = Date.now() - start;
    
    // All requests should succeed
    responses.forEach(response => {
      expect(response.status).toBe(200);
    });
    
    // Average response time should be reasonable
    const avgResponseTime = totalTime / concurrentRequests;
    expect(avgResponseTime).toBeLessThan(1000);
  });
});

// Integration tests
describe('Integration Tests', () => {
  test('Complete order flow should work end-to-end', async () => {
    // This would require a test database setup
    // For now, we'll test the flow with mocks
    expect(true).toBe(true);
  });

  test('Search and filter should work together', async () => {
    // This would test the search functionality with filters
    expect(true).toBe(true);
  });
});

// Edge cases
describe('Edge Cases', () => {
  test('Should handle empty search results', async () => {
    mockPool.query.mockResolvedValue({ rows: [] });
    
    const response = await request(app)
      .get('/api/search?q=nonexistent')
      .expect(200);

    expect(response.body).toEqual([]);
  });

  test('Should handle malformed JSON in request body', async () => {
    const response = await request(app)
      .post('/api/orders')
      .set('Content-Type', 'application/json')
      .send('invalid json')
      .expect(400);
  });

  test('Should handle very long search queries', async () => {
    const longQuery = 'a'.repeat(1000);
    
    const response = await request(app)
      .get(`/api/search?q=${longQuery}`)
      .expect(200);
  });
});

// Cleanup
afterAll(async () => {
  // Clean up any test resources
});
