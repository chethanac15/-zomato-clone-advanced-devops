// Global test teardown file for Jest
// This file runs once after all tests

module.exports = async () => {
  console.log('Running global test teardown...');
  
  // Clean up global test resources
  if (global.testDbPool) {
    try {
      await global.testDbPool.end();
    } catch (error) {
      console.error('Error closing test database pool:', error);
    }
  }
  
  if (global.testRedis) {
    try {
      await global.testRedis.quit();
    } catch (error) {
      console.error('Error closing test Redis connection:', error);
    }
  }
  
  // Clear global test data
  global.testData = null;
  global.testDbPool = null;
  global.testRedis = null;
  
  console.log('Global test teardown complete');
};
