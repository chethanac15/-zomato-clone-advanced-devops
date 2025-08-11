// Environment setup file for Jest tests
// This file runs before each test file to set up the environment

// Set test environment variables
process.env.NODE_ENV = 'test';
process.env.PORT = 3001;
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/zomato_test';
process.env.REDIS_URL = 'redis://localhost:6379/1';
process.env.JWT_SECRET = 'test-secret-key';
process.env.ENCRYPTION_KEY = 'test-encryption-key-32-chars-long';

// Mock environment variables for testing
process.env.AWS_ACCESS_KEY_ID = 'test-access-key';
process.env.AWS_SECRET_ACCESS_KEY = 'test-secret-key';
process.env.AWS_REGION = 'us-east-1';
process.env.GOOGLE_CLOUD_PROJECT = 'test-project';
process.env.AZURE_STORAGE_CONNECTION_STRING = 'test-connection-string';

// Set test timeouts
jest.setTimeout(10000);

// Suppress console output during tests unless explicitly enabled
if (process.env.TEST_VERBOSE !== 'true') {
  const originalConsoleLog = console.log;
  const originalConsoleError = console.error;
  const originalConsoleWarn = console.warn;
  
  console.log = jest.fn();
  console.error = jest.fn();
  console.warn = jest.fn();
  
  // Restore console after tests
  afterAll(() => {
    console.log = originalConsoleLog;
    console.error = originalConsoleError;
    console.warn = originalConsoleWarn;
  });
}

// Global test configuration
global.testConfig = {
  baseUrl: 'http://localhost:3001',
  timeout: 10000,
  retries: 3
};

console.log('Test environment setup complete');
