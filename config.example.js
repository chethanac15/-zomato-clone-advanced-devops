// Configuration file for Zomato Clone Advanced DevOps Project
// Copy this file to config.js and update the values as needed

module.exports = {
  // Application Configuration
  app: {
    name: 'Zomato Clone Advanced',
    version: '1.0.0',
    port: process.env.PORT || 3000,
    host: process.env.HOST || '0.0.0.0',
    environment: process.env.NODE_ENV || 'development'
  },

  // Database Configuration
  database: {
    url: process.env.DATABASE_URL || 'postgresql://postgres:password@localhost:5432/zomato',
    host: process.env.POSTGRES_HOST || 'localhost',
    port: process.env.POSTGRES_PORT || 5432,
    name: process.env.POSTGRES_DB || 'zomato',
    user: process.env.POSTGRES_USER || 'postgres',
    password: process.env.POSTGRES_PASSWORD || 'password',
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    pool: {
      min: 2,
      max: 10,
      acquireTimeoutMillis: 30000,
      createTimeoutMillis: 30000,
      destroyTimeoutMillis: 5000,
      idleTimeoutMillis: 30000,
      reapIntervalMillis: 1000,
      createRetryIntervalMillis: 100
    }
  },

  // Redis Configuration
  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379',
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD || null,
    db: process.env.REDIS_DB || 0,
    retryDelayOnFailover: 100,
    maxRetriesPerRequest: 3
  },

  // Security Configuration
  security: {
    jwtSecret: process.env.JWT_SECRET || 'your-super-secret-jwt-key-here',
    bcryptRounds: parseInt(process.env.BCRYPT_ROUNDS) || 12,
    rateLimit: {
      windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
      max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100
    },
    cors: {
      origin: process.env.CORS_ORIGIN || '*',
      credentials: true
    },
    helmet: {
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net", "https://cdnjs.cloudflare.com"],
          scriptSrc: ["'self'", "https://cdn.jsdelivr.net", "https://cdnjs.cloudflare.com"],
          imgSrc: ["'self'", "data:", "https:"],
          fontSrc: ["'self'", "https://cdn.jsdelivr.net", "https://cdnjs.cloudflare.com"]
        }
      }
    }
  },

  // Monitoring Configuration
  monitoring: {
    prometheus: {
      port: parseInt(process.env.PROMETHEUS_PORT) || 9090,
      collectDefaultMetrics: true,
      customMetrics: {
        httpRequestDuration: true,
        httpRequestsTotal: true,
        orderSuccessRate: true
      }
    },
    grafana: {
      port: parseInt(process.env.GRAFANA_PORT) || 3001,
      adminPassword: process.env.GRAFANA_ADMIN_PASSWORD || 'admin'
    },
    jaeger: {
      port: parseInt(process.env.JAEGER_PORT) || 16686,
      enabled: process.env.JAEGER_ENABLED === 'true'
    }
  },

  // Cloud Provider Configuration
  cloud: {
    aws: {
      region: process.env.AWS_REGION || 'us-west-2',
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
    },
    gcp: {
      projectId: process.env.GCP_PROJECT_ID,
      region: process.env.GCP_REGION || 'us-central1',
      credentialsFile: process.env.GCP_CREDENTIALS_FILE
    },
    azure: {
      subscriptionId: process.env.AZURE_SUBSCRIPTION_ID,
      tenantId: process.env.AZURE_TENANT_ID,
      clientId: process.env.AZURE_CLIENT_ID,
      clientSecret: process.env.AZURE_CLIENT_SECRET
    }
  },

  // Kubernetes Configuration
  kubernetes: {
    namespace: process.env.K8S_NAMESPACE || 'zomato-project',
    configPath: process.env.KUBECONFIG || '~/.kube/config',
    openkruise: {
      enabled: true,
      features: ['AdvancedStatefulSet', 'SidecarSet', 'WorkloadSpread', 'PodUnavailableBudget']
    }
  },

  // CI/CD Configuration
  cicd: {
    jenkins: {
      url: process.env.JENKINS_URL || 'http://localhost:8080',
      user: process.env.JENKINS_USER || 'admin',
      apiToken: process.env.JENKINS_API_TOKEN
    },
    argocd: {
      server: process.env.ARGOCD_SERVER || 'localhost:8080',
      username: process.env.ARGOCD_USERNAME || 'admin',
      password: process.env.ARGOCD_PASSWORD
    }
  },

  // Testing Configuration
  testing: {
    database: {
      url: process.env.TEST_DATABASE_URL || 'postgresql://test:test@localhost:5432/zomato_test'
    },
    redis: {
      url: process.env.TEST_REDIS_URL || 'redis://localhost:6379/1'
    },
    coverage: {
      threshold: parseInt(process.env.COVERAGE_THRESHOLD) || 80
    },
    timeout: parseInt(process.env.TEST_TIMEOUT) || 10000
  },

  // Logging Configuration
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    file: {
      path: process.env.LOG_FILE_PATH || './logs/app.log',
      maxSize: process.env.LOG_MAX_SIZE || '10m',
      maxFiles: parseInt(process.env.LOG_MAX_FILES) || 5
    },
    console: {
      enabled: process.env.LOG_CONSOLE_ENABLED !== 'false'
    }
  },

  // Performance Configuration
  performance: {
    compression: {
      level: parseInt(process.env.COMPRESSION_LEVEL) || 6,
      threshold: 1024
    },
    cache: {
      ttl: parseInt(process.env.CACHE_TTL) || 300,
      maxKeys: 1000
    }
  }
};
