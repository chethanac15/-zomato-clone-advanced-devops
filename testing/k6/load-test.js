import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";

// Custom metrics for business KPIs
const businessMetrics = {
  orderSuccessRate: new Rate('order_success_rate'),
  orderLatency: new Trend('order_latency'),
  searchLatency: new Trend('search_latency'),
  paymentSuccessRate: new Rate('payment_success_rate'),
  userRegistrationRate: new Rate('user_registration_rate'),
  restaurantLoadTime: new Trend('restaurant_load_time'),
  cartOperations: new Counter('cart_operations'),
  apiErrors: new Counter('api_errors'),
  databaseQueries: new Counter('database_queries'),
  cacheHits: new Counter('cache_hits'),
  cacheMisses: new Counter('cache_misses')
};

// Test configuration
export const options = {
  stages: [
    // Ramp-up phase
    { duration: '2m', target: 50 },   // Ramp up to 50 users
    { duration: '5m', target: 100 },  // Ramp up to 100 users
    { duration: '10m', target: 200 }, // Ramp up to 200 users
    { duration: '15m', target: 200 }, // Stay at 200 users
    { duration: '5m', target: 100 },  // Ramp down to 100 users
    { duration: '2m', target: 0 },    // Ramp down to 0 users
  ],
  
  thresholds: {
    // Performance thresholds
    http_req_duration: ['p(95)<500', 'p(99)<1000'], // 95% under 500ms, 99% under 1s
    http_req_failed: ['rate<0.05'],                  // Error rate under 5%
    http_req_rate: ['rate>100'],                     // Request rate above 100 req/s
    
    // Business metric thresholds
    'order_success_rate': ['rate>0.95'],              // Order success rate above 95%
    'order_latency': ['p(95)<2000'],                 // Order latency under 2s
    'search_latency': ['p(95)<1000'],                // Search latency under 1s
    'payment_success_rate': ['rate>0.98'],            // Payment success rate above 98%
    'restaurant_load_time': ['p(95)<1500'],          // Restaurant page load under 1.5s
  },
  
  // Scenarios for different user behaviors
  scenarios: {
    // Regular users browsing and ordering
    regular_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 30 },
        { duration: '10m', target: 100 },
        { duration: '5m', target: 0 }
      ],
      gracefulRampDown: '30s',
      exec: 'regularUserFlow'
    },
    
    // Power users with high order frequency
    power_users: {
      executor: 'constant-vus',
      vus: 20,
      duration: '20m',
      exec: 'powerUserFlow'
    },
    
    // New user registration flow
    new_users: {
      executor: 'per-vu-iterations',
      vus: 10,
      iterations: 5,
      exec: 'newUserFlow'
    },
    
    // Search and discovery users
    search_users: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1m',
      preAllocatedVUs: 50,
      maxVUs: 100,
      stages: [
        { duration: '5m', target: 50 },
        { duration: '10m', target: 100 },
        { duration: '5m', target: 0 }
      ],
      exec: 'searchUserFlow'
    }
  }
};

// Test data and configuration
const BASE_URL = __ENV.BASE_URL || 'http://zomato-app:3000';
const API_VERSION = '/api/v1';

// Test data for realistic scenarios
const testData = {
  restaurants: [
    { id: 1, name: 'Pizza Palace', cuisine: 'Italian', rating: 4.5 },
    { id: 2, name: 'Burger House', cuisine: 'American', rating: 4.2 },
    { id: 3, name: 'Sushi Bar', cuisine: 'Japanese', rating: 4.7 },
    { id: 4, name: 'Taco Corner', cuisine: 'Mexican', rating: 4.0 },
    { id: 5, name: 'Curry House', cuisine: 'Indian', rating: 4.3 }
  ],
  
  users: [
    { email: 'user1@test.com', password: 'password123', name: 'John Doe' },
    { email: 'user2@test.com', password: 'password123', name: 'Jane Smith' },
    { email: 'user3@test.com', password: 'password123', name: 'Bob Johnson' }
  ],
  
  menuItems: [
    { id: 1, name: 'Margherita Pizza', price: 15.99, category: 'Pizza' },
    { id: 2, name: 'Cheeseburger', price: 12.99, category: 'Burgers' },
    { id: 3, name: 'California Roll', price: 18.99, category: 'Sushi' }
  ]
};

// Helper functions
function generateRandomUser() {
  const randomId = Math.floor(Math.random() * 10000);
  return {
    email: `user${randomId}@test.com`,
    password: 'password123',
    name: `User ${randomId}`,
    phone: `+1${Math.floor(Math.random() * 9000000000) + 1000000000}`
  };
}

function generateRandomOrder() {
  const restaurant = testData.restaurants[Math.floor(Math.random() * testData.restaurants.length)];
  const items = [];
  const numItems = Math.floor(Math.random() * 3) + 1;
  
  for (let i = 0; i < numItems; i++) {
    const menuItem = testData.menuItems[Math.floor(Math.random() * testData.menuItems.length)];
    items.push({
      itemId: menuItem.id,
      quantity: Math.floor(Math.random() * 2) + 1,
      price: menuItem.price
    });
  }
  
  return {
    restaurantId: restaurant.id,
    items: items,
    deliveryAddress: {
      street: '123 Test Street',
      city: 'Test City',
      state: 'TS',
      zipCode: '12345'
    },
    paymentMethod: 'credit_card'
  };
}

// Regular user flow - browsing, searching, and ordering
export function regularUserFlow() {
  const startTime = Date.now();
  
  // 1. Browse restaurants
  const browseResponse = http.get(`${BASE_URL}${API_VERSION}/restaurants`);
  check(browseResponse, {
    'browse_restaurants_success': (r) => r.status === 200,
    'browse_restaurants_fast': (r) => r.timings.duration < 500
  });
  
  if (browseResponse.status === 200) {
    businessMetrics.restaurantLoadTime.add(browseResponse.timings.duration);
  }
  
  sleep(1);
  
  // 2. Search for specific cuisine
  const searchQuery = testData.restaurants[Math.floor(Math.random() * testData.restaurants.length)].cuisine;
  const searchResponse = http.get(`${BASE_URL}${API_VERSION}/restaurants/search?cuisine=${searchQuery}`);
  
  const searchLatency = searchResponse.timings.duration;
  businessMetrics.searchLatency.add(searchLatency);
  
  check(searchResponse, {
    'search_restaurants_success': (r) => r.status === 200,
    'search_restaurants_fast': (r) => r.timings.duration < 1000
  });
  
  sleep(2);
  
  // 3. View restaurant details
  const restaurantId = testData.restaurants[Math.floor(Math.random() * testData.restaurants.length)].id;
  const restaurantResponse = http.get(`${BASE_URL}${API_VERSION}/restaurants/${restaurantId}`);
  
  check(restaurantResponse, {
    'restaurant_details_success': (r) => r.status === 200,
    'restaurant_details_fast': (r) => r.timings.duration < 800
  });
  
  sleep(1);
  
  // 4. Add items to cart
  const cartItem = {
    restaurantId: restaurantId,
    itemId: testData.menuItems[0].id,
    quantity: 2
  };
  
  const addToCartResponse = http.post(`${BASE_URL}${API_VERSION}/cart/add`, JSON.stringify(cartItem), {
    headers: { 'Content-Type': 'application/json' }
  });
  
  if (addToCartResponse.status === 200) {
    businessMetrics.cartOperations.add(1);
  }
  
  check(addToCartResponse, {
    'add_to_cart_success': (r) => r.status === 200
  });
  
  sleep(1);
  
  // 5. Place order (30% probability to simulate real user behavior)
  if (Math.random() < 0.3) {
    const orderData = generateRandomOrder();
    const orderResponse = http.post(`${BASE_URL}${API_VERSION}/orders`, JSON.stringify(orderData), {
      headers: { 'Content-Type': 'application/json' }
    });
    
    const orderLatency = orderResponse.timings.duration;
    businessMetrics.orderLatency.add(orderLatency);
    
    if (orderResponse.status === 200) {
      businessMetrics.orderSuccessRate.add(1);
    } else {
      businessMetrics.orderSuccessRate.add(0);
      businessMetrics.apiErrors.add(1);
    }
    
    check(orderResponse, {
      'place_order_success': (r) => r.status === 200,
      'order_processing_fast': (r) => r.timings.duration < 2000
    });
  }
  
  const totalTime = Date.now() - startTime;
  console.log(`Regular user flow completed in ${totalTime}ms`);
}

// Power user flow - high frequency ordering
export function powerUserFlow() {
  // Power users place orders more frequently
  for (let i = 0; i < 3; i++) {
    const orderData = generateRandomOrder();
    const orderResponse = http.post(`${BASE_URL}${API_VERSION}/orders`, JSON.stringify(orderData), {
      headers: { 'Content-Type': 'application/json' }
    });
    
    const orderLatency = orderResponse.timings.duration;
    businessMetrics.orderLatency.add(orderLatency);
    
    if (orderResponse.status === 200) {
      businessMetrics.orderSuccessRate.add(1);
    } else {
      businessMetrics.orderSuccessRate.add(0);
      businessMetrics.apiErrors.add(1);
    }
    
    check(orderResponse, {
      'power_user_order_success': (r) => r.status === 200,
      'power_user_order_fast': (r) => r.timings.duration < 1500
    });
    
    sleep(1);
  }
  
  // Power users also browse more
  const browseResponse = http.get(`${BASE_URL}${API_VERSION}/restaurants`);
  check(browseResponse, {
    'power_user_browse_success': (r) => r.status === 200
  });
  
  sleep(2);
}

// New user registration flow
export function newUserFlow() {
  const userData = generateRandomUser();
  
  // 1. Register new user
  const registerResponse = http.post(`${BASE_URL}${API_VERSION}/auth/register`, JSON.stringify(userData), {
    headers: { 'Content-Type': 'application/json' }
  });
  
  if (registerResponse.status === 201) {
    businessMetrics.userRegistrationRate.add(1);
  } else {
    businessMetrics.userRegistrationRate.add(0);
    businessMetrics.apiErrors.add(1);
  }
  
  check(registerResponse, {
    'user_registration_success': (r) => r.status === 201,
    'registration_fast': (r) => r.timings.duration < 1000
  });
  
  sleep(1);
  
  // 2. Login with new credentials
  const loginData = {
    email: userData.email,
    password: userData.password
  };
  
  const loginResponse = http.post(`${BASE_URL}${API_VERSION}/auth/login`, JSON.stringify(loginData), {
    headers: { 'Content-Type': 'application/json' }
  });
  
  check(loginResponse, {
    'user_login_success': (r) => r.status === 200,
    'login_fast': (r) => r.timings.duration < 800
  });
  
  sleep(1);
  
  // 3. Complete profile setup
  const profileData = {
    name: userData.name,
    phone: userData.phone,
    preferences: ['Italian', 'American']
  };
  
  const profileResponse = http.put(`${BASE_URL}${API_VERSION}/user/profile`, JSON.stringify(profileData), {
    headers: { 'Content-Type': 'application/json' }
  });
  
  check(profileResponse, {
    'profile_update_success': (r) => r.status === 200
  });
  
  sleep(2);
}

// Search-focused user flow
export function searchUserFlow() {
  // Search users focus on discovery
  const searchQueries = ['pizza', 'burger', 'sushi', 'indian', 'mexican', 'chinese'];
  
  for (let i = 0; i < 5; i++) {
    const query = searchQueries[Math.floor(Math.random() * searchQueries.length)];
    const searchResponse = http.get(`${BASE_URL}${API_VERSION}/restaurants/search?cuisine=${query}`);
    
    const searchLatency = searchResponse.timings.duration;
    businessMetrics.searchLatency.add(searchLatency);
    
    check(searchResponse, {
      'search_query_success': (r) => r.status === 200,
      'search_query_fast': (r) => r.timings.duration < 1000
    });
    
    sleep(1);
    
    // Sometimes view restaurant details
    if (Math.random() < 0.4) {
      const restaurantId = Math.floor(Math.random() * 100) + 1;
      const restaurantResponse = http.get(`${BASE_URL}${API_VERSION}/restaurants/${restaurantId}`);
      
      check(restaurantResponse, {
        'search_user_restaurant_view_success': (r) => r.status === 200
      });
      
      sleep(1);
    }
  }
}

// Setup function - runs once before the test
export function setup() {
  console.log('Setting up K6 performance test...');
  
  // Verify application is accessible
  const healthCheck = http.get(`${BASE_URL}/health`);
  if (healthCheck.status !== 200) {
    throw new Error('Application is not accessible');
  }
  
  console.log('Application is accessible, starting performance test...');
  return { baseUrl: BASE_URL };
}

// Teardown function - runs once after the test
export function teardown(data) {
  console.log('Performance test completed');
  console.log(`Base URL: ${data.baseUrl}`);
  
  // Generate HTML report
  return htmlReport({
    title: 'Zomato Clone Performance Test Report',
    description: 'Comprehensive performance test results for Zomato Clone application',
    includeMetrics: [
      'http_req_duration',
      'http_req_failed',
      'order_success_rate',
      'order_latency',
      'search_latency',
      'payment_success_rate',
      'restaurant_load_time'
    ]
  });
}

// Default function for single VU execution
export default function() {
  // Randomly choose a user flow based on weights
  const flowChoice = Math.random();
  
  if (flowChoice < 0.6) {
    regularUserFlow();
  } else if (flowChoice < 0.8) {
    powerUserFlow();
  } else if (flowChoice < 0.9) {
    newUserFlow();
  } else {
    searchUserFlow();
  }
}

// Handle test events
export function handleSummary(data) {
  console.log('Test Summary:');
  console.log(`Total Requests: ${data.metrics.http_reqs.values.count}`);
  console.log(`Failed Requests: ${data.metrics.http_req_failed.values.passes}`);
  console.log(`Average Response Time: ${data.metrics.http_req_duration.values.avg}ms`);
  console.log(`95th Percentile: ${data.metrics.http_req_duration.values['p(95)']}ms`);
  
  return {
    'performance-test-summary.json': JSON.stringify(data, null, 2),
    'performance-test-report.html': htmlReport(data)
  };
}
