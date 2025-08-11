// Test setup file for Jest
// This file runs before each test file

// Set test environment variables
process.env.NODE_ENV = 'test';
process.env.PORT = 3001;
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/zomato_test';
process.env.REDIS_URL = 'redis://localhost:6379/1';

// Increase timeout for tests
jest.setTimeout(10000);

// Global test utilities
global.testUtils = {
  // Generate random test data
  generateTestRestaurant: () => ({
    name: `Test Restaurant ${Math.random().toString(36).substr(2, 9)}`,
    cuisine: 'Test Cuisine',
    rating: 4.5,
    delivery_time: 30,
    min_order: 15.00,
    address: '123 Test St, Test City',
    phone: '+1-555-0101'
  }),

  generateTestMenuItem: (restaurantId) => ({
    restaurant_id: restaurantId,
    name: `Test Dish ${Math.random().toString(36).substr(2, 9)}`,
    description: 'Test dish description',
    price: 15.99,
    category: 'Main Course',
    is_vegetarian: false,
    is_available: true
  }),

  generateTestOrder: (userId, restaurantId) => ({
    user_id: userId,
    restaurant_id: restaurantId,
    items: [
      { menu_item_id: 1, quantity: 2, special_instructions: 'Extra spicy' }
    ],
    delivery_address: '123 Test St, Test City'
  }),

  // Wait for async operations
  wait: (ms) => new Promise(resolve => setTimeout(resolve, ms)),

  // Generate random string
  randomString: (length = 10) => Math.random().toString(36).substr(2, length),

  // Generate random email
  randomEmail: () => `test.${Math.random().toString(36).substr(2, 9)}@example.com`,

  // Generate random phone number
  randomPhone: () => `+1-555-${Math.random().toString().substr(2, 3)}-${Math.random().toString().substr(2, 4)}`,

  // Generate random price
  randomPrice: (min = 5, max = 50) => parseFloat((Math.random() * (max - min) + min).toFixed(2)),

  // Generate random rating
  randomRating: () => parseFloat((Math.random() * 5).toFixed(1)),

  // Generate random delivery time
  randomDeliveryTime: (min = 15, max = 60) => Math.floor(Math.random() * (max - min + 1)) + min,

  // Generate random boolean
  randomBoolean: () => Math.random() > 0.5,

  // Generate random array element
  randomElement: (array) => array[Math.floor(Math.random() * array.length)],

  // Generate random subset of array
  randomSubset: (array, size) => {
    const shuffled = [...array].sort(() => 0.5 - Math.random());
    return shuffled.slice(0, size);
  },

  // Mock database response
  mockDbResponse: (data) => ({
    rows: Array.isArray(data) ? data : [data],
    rowCount: Array.isArray(data) ? data.length : 1
  }),

  // Mock error response
  mockDbError: (message = 'Database error') => {
    const error = new Error(message);
    error.code = 'DB_ERROR';
    return error;
  },

  // Validate response structure
  validateRestaurantStructure: (restaurant) => {
    expect(restaurant).toHaveProperty('id');
    expect(restaurant).toHaveProperty('name');
    expect(restaurant).toHaveProperty('cuisine');
    expect(restaurant).toHaveProperty('rating');
    expect(restaurant).toHaveProperty('delivery_time');
    expect(restaurant).toHaveProperty('min_order');
    expect(restaurant).toHaveProperty('address');
    expect(restaurant).toHaveProperty('phone');
    expect(restaurant).toHaveProperty('created_at');
    expect(restaurant).toHaveProperty('updated_at');
  },

  validateMenuItemStructure: (menuItem) => {
    expect(menuItem).toHaveProperty('id');
    expect(menuItem).toHaveProperty('restaurant_id');
    expect(menuItem).toHaveProperty('name');
    expect(menuItem).toHaveProperty('description');
    expect(menuItem).toHaveProperty('price');
    expect(menuItem).toHaveProperty('category');
    expect(menuItem).toHaveProperty('is_vegetarian');
    expect(menuItem).toHaveProperty('is_available');
    expect(menuItem).toHaveProperty('created_at');
  },

  validateOrderStructure: (order) => {
    expect(order).toHaveProperty('id');
    expect(order).toHaveProperty('user_id');
    expect(order).toHaveProperty('restaurant_id');
    expect(order).toHaveProperty('total_amount');
    expect(order).toHaveProperty('status');
    expect(order).toHaveProperty('delivery_address');
    expect(order).toHaveProperty('created_at');
    expect(order).toHaveProperty('updated_at');
  },

  // Performance testing utilities
  measurePerformance: async (fn, iterations = 1000) => {
    const start = process.hrtime.bigint();
    
    for (let i = 0; i < iterations; i++) {
      await fn();
    }
    
    const end = process.hrtime.bigint();
    const duration = Number(end - start) / 1000000; // Convert to milliseconds
    
    return {
      totalTime: duration,
      averageTime: duration / iterations,
      iterations: iterations
    };
  },

  // Load testing utilities
  simulateLoad: async (concurrentUsers, duration, fn) => {
    const startTime = Date.now();
    const results = [];
    
    while (Date.now() - startTime < duration) {
      const promises = Array(concurrentUsers).fill().map(() => fn());
      const batchResults = await Promise.allSettled(promises);
      results.push(...batchResults);
      
      // Small delay between batches
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    return {
      totalRequests: results.length,
      successfulRequests: results.filter(r => r.status === 'fulfilled').length,
      failedRequests: results.filter(r => r.status === 'rejected').length,
      duration: Date.now() - startTime
    };
  },

  // Database testing utilities
  setupTestDatabase: async () => {
    // This would set up a test database
    // For now, just return a mock
    return {
      connected: true,
      database: 'zomato_test'
    };
  },

  teardownTestDatabase: async () => {
    // This would clean up the test database
    // For now, just return a mock
    return {
      cleaned: true
    };
  },

  // API testing utilities
  makeAuthenticatedRequest: (app, method, url, data = null, token = 'test-token') => {
    const request = app[method.toLowerCase()](url);
    
    if (token) {
      request.set('Authorization', `Bearer ${token}`);
    }
    
    if (data) {
      request.send(data);
    }
    
    return request;
  },

  // Validation utilities
  validatePagination: (response, page = 1, limit = 10) => {
    expect(response.body).toHaveProperty('data');
    expect(response.body).toHaveProperty('pagination');
    expect(response.body.pagination).toHaveProperty('page');
    expect(response.body.pagination).toHaveProperty('limit');
    expect(response.body.pagination).toHaveProperty('total');
    expect(response.body.pagination).toHaveProperty('pages');
    
    expect(response.body.pagination.page).toBe(page);
    expect(response.body.pagination.limit).toBe(limit);
    expect(response.body.pagination.total).toBeGreaterThanOrEqual(0);
    expect(response.body.pagination.pages).toBeGreaterThanOrEqual(0);
  },

  validateErrorResponse: (response, statusCode, errorMessage = null) => {
    expect(response.status).toBe(statusCode);
    expect(response.body).toHaveProperty('error');
    
    if (errorMessage) {
      expect(response.body.error).toContain(errorMessage);
    }
  },

  validateSuccessResponse: (response, statusCode = 200) => {
    expect(response.status).toBe(statusCode);
    expect(response.body).not.toHaveProperty('error');
  }
};

// Console logging for tests
const originalConsoleLog = console.log;
const originalConsoleError = console.error;
const originalConsoleWarn = console.warn;

// Suppress console output during tests unless explicitly enabled
if (process.env.TEST_VERBOSE !== 'true') {
  console.log = jest.fn();
  console.error = jest.fn();
  console.warn = jest.fn();
}

// Restore console after tests
afterAll(() => {
  console.log = originalConsoleLog;
  console.error = originalConsoleError;
  console.warn = originalConsoleWarn;
});

// Global before each hook
beforeEach(() => {
  // Clear all mocks
  jest.clearAllMocks();
  
  // Reset test data
  global.testData = {
    restaurants: [],
    menuItems: [],
    orders: [],
    users: []
  };
});

// Global after each hook
afterEach(() => {
  // Clean up any test resources
  if (global.testData) {
    global.testData = {};
  }
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  // Don't exit the process, just log the error
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  // Don't exit the process, just log the error
});

// Export test utilities for use in test files
module.exports = global.testUtils;
