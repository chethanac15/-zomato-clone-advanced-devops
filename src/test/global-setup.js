// Global test setup file for Jest
// This file runs once before all tests

const { Pool } = require('pg');
const Redis = require('ioredis');

// Global test database connection
global.testDbPool = null;
global.testRedis = null;

module.exports = async () => {
  console.log('Setting up global test environment...');
  
  // Set test environment variables
  process.env.NODE_ENV = 'test';
  process.env.PORT = 3001;
  process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/zomato_test';
  process.env.REDIS_URL = 'redis://localhost:6379/1';
  
  // Initialize test database connection (mock)
  global.testDbPool = {
    query: jest.fn(),
    connect: jest.fn(),
    end: jest.fn()
  };
  
  // Initialize test Redis connection (mock)
  global.testRedis = {
    ping: jest.fn().mockResolvedValue('PONG'),
    get: jest.fn(),
    setex: jest.fn(),
    quit: jest.fn()
  };
  
  console.log('Global test environment setup complete');
};

// Global teardown
module.exports.teardown = async () => {
  console.log('Cleaning up global test environment...');
  
  if (global.testDbPool) {
    await global.testDbPool.end();
  }
  
  if (global.testRedis) {
    await global.testRedis.quit();
  }
  
  console.log('Global test environment cleanup complete');
};
