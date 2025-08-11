module.exports = {
  // Test environment
  testEnvironment: 'node',
  
  // Test file patterns
  testMatch: [
    '**/src/**/*.test.js',
    '**/src/**/*.spec.js',
    '**/tests/**/*.test.js',
    '**/tests/**/*.spec.js'
  ],
  
  // Test setup files
  setupFilesAfterEnv: [
    '<rootDir>/src/test/setup.js'
  ],
  
  // Coverage configuration
  collectCoverage: true,
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/**/*.test.js',
    '!src/**/*.spec.js',
    '!src/test/**/*.js',
    '!src/public/**/*.js'
  ],
  
  // Coverage thresholds
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  
  // Coverage reporters
  coverageReporters: [
    'text',
    'lcov',
    'html',
    'json'
  ],
  
  // Coverage directory
  coverageDirectory: 'coverage',
  
  // Test timeout
  testTimeout: 10000,
  
  // Verbose output
  verbose: true,
  
  // Clear mocks between tests
  clearMocks: true,
  
  // Restore mocks between tests
  restoreMocks: true,
  
  // Module file extensions
  moduleFileExtensions: [
    'js',
    'json'
  ],
  
  // Transform configuration
  transform: {},
  
  // Module name mapping
  moduleNameMapping: {
    '^@/(.*)$': '<rootDir>/src/$1'
  },
  
  // Test path ignore patterns
  testPathIgnorePatterns: [
    '/node_modules/',
    '/dist/',
    '/build/',
    '/coverage/'
  ],
  
  // Watch plugins
  watchPlugins: [
    'jest-watch-typeahead/filename',
    'jest-watch-typeahead/testname'
  ],
  
  // Global test setup
  globalSetup: '<rootDir>/src/test/global-setup.js',
  
  // Global test teardown
  globalTeardown: '<rootDir>/src/test/global-teardown.js',
  
  // Test results processor
  testResultsProcessor: 'jest-sonar-reporter',
  
  // Reporters
  reporters: [
    'default',
    [
      'jest-junit',
      {
        outputDirectory: 'reports/junit',
        outputName: 'js-test-results.xml',
        classNameTemplate: '{classname}-{title}',
        titleTemplate: '{title}',
        ancestorSeparator: ' › ',
        usePathForSuiteName: true
      }
    ]
  ],
  
  // Environment variables
  setupFiles: [
    '<rootDir>/src/test/env-setup.js'
  ],
  
  // Test environment options
  testEnvironmentOptions: {
    url: 'http://localhost:3000'
  },
  
  // Module resolution
  moduleDirectories: [
    'node_modules',
    'src'
  ],
  
  // Extensions to treat as ES modules
  extensionsToTreatAsEsm: [],
  
  // Transform ignore patterns
  transformIgnorePatterns: [
    'node_modules/(?!(.*\\.mjs$))'
  ],
  
  // Unmocked module path patterns
  unmockedModulePathPatterns: [
    'node_modules/react',
    'node_modules/react-dom'
  ],
  
  // Test location
  testLocationInResults: true,
  
  // Error on missing coverage
  errorOnDeprecated: true,
  
  // Force coverage collection
  forceCoverageMatch: [
    'src/**/*.js'
  ],
  
  // Coverage provider
  coverageProvider: 'v8',
  
  // Worker threads
  maxWorkers: '50%',
  
  // Cache
  cache: true,
  cacheDirectory: '<rootDir>/.jest-cache',
  
  // Detect open handles
  detectOpenHandles: true,
  
  // Force exit
  forceExit: false,
  
  // Log heap usage
  logHeapUsage: false,
  
  // Max concurrency
  maxConcurrency: 5,
  
  // Randomize
  randomize: false,
  
  // Run tests in band
  runInBand: false,
  
  // Show seed
  showSeed: false,
  
  // Silent
  silent: false,
  
  // Update snapshots
  updateSnapshot: false,
  
  // Use the beta APIs
  useStderr: false,
  
  // Watch
  watch: false,
  
  // Watch all
  watchAll: false,
  
  // Watchman
  watchman: true
};
