# Docker Setup for Skin Dermatology Chatbot

This document explains how to run the Skin Dermatology Chatbot using Docker.

## 🐳 Quick Start

### Prerequisites
- Docker and Docker Compose installed
- OpenAI API key

### 1. Environment Setup
```bash
# Copy environment template
cp env.example .env

# Edit .env with your values
# OPENAI_API_KEY=your_actual_openai_api_key
# SECRET_KEY_BASE=generate_with_rails_secret
```

### 2. Development Environment
```bash
# Start development environment
./docker-setup.sh dev

# Setup database
./docker-setup.sh setup dev

# View logs
./docker-setup.sh logs dev
```

Access your app at: http://localhost:3000

### 3. Production Environment
```bash
# Start production environment
./docker-setup.sh prod

# Setup database
./docker-setup.sh setup

# View logs
./docker-setup.sh logs
```

## 📁 Docker Files

### Core Files
- **`Dockerfile`** - Original production Dockerfile (Rails 8 optimized)
- **`Dockerfile.production`** - Enhanced production build
- **`Dockerfile.dev`** - Development environment
- **`docker-compose.yml`** - Production services
- **`docker-compose.dev.yml`** - Development services

### Services

#### Production (`docker-compose.yml`)
- **web** - Rails application (port 3000)
- **sidekiq** - Background job processor
- **redis** - Cache and job queue

#### Development (`docker-compose.dev.yml`)
- **web** - Rails development server (port 3000)
- **sidekiq** - Background job processor
- **redis** - Cache and job queue (port 6379)
- **db** - PostgreSQL database (port 5432)

## 🛠️ Commands

### Using docker-setup.sh script:
```bash
./docker-setup.sh dev      # Start development
./docker-setup.sh prod     # Start production
./docker-setup.sh build    # Build images
./docker-setup.sh clean    # Clean up
./docker-setup.sh logs     # View logs
./docker-setup.sh shell    # Open shell
./docker-setup.sh setup    # Database setup
```

### Manual Docker commands:

#### Development
```bash
# Start services
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Shell access
docker-compose -f docker-compose.dev.yml exec web bash

# Stop services
docker-compose -f docker-compose.dev.yml down
```

#### Production
```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Shell access
docker-compose exec web bash

# Stop services
docker-compose down
```

## 🔧 Environment Variables

### Required
- `OPENAI_API_KEY` - Your OpenAI API key for vision analysis
- `SECRET_KEY_BASE` - Rails secret key (generate with `rails secret`)

### Optional
- `RAILS_MASTER_KEY` - For encrypted credentials
- `REDIS_URL` - Redis connection URL (auto-configured)
- `DATABASE_URL` - Database URL (auto-configured in dev)

## 📦 Volumes

### Development
- `postgres_dev_data` - PostgreSQL data persistence
- `redis_dev_data` - Redis data persistence
- `bundle_cache` - Gem cache for faster builds
- `node_modules` - NPM packages cache

### Production
- `redis_data` - Redis data persistence
- `rails_logs` - Application logs
- `./storage` - Rails storage (mounted from host)

## 🚀 Features

### AI-Powered Skin Analysis
- OpenAI vision analysis for uploaded photos
- Face detection to prevent non-facial analysis
- AI-powered product recommendations

### Background Processing
- Sidekiq for asynchronous image processing
- Redis for job queuing and caching
- Automatic retry mechanisms

### Production Ready
- Multi-stage builds for optimized images
- Health checks for all services
- Proper security with non-root user
- Asset precompilation and optimization

## 🔍 Troubleshooting

### Common Issues

#### Port conflicts
```bash
# Check what's using port 3000
lsof -i :3000

# Use different port
docker-compose up -d -p 3001:3000
```

#### Database issues
```bash
# Reset database
./docker-setup.sh clean
./docker-setup.sh dev
./docker-setup.sh setup dev
```

#### OpenAI API errors
- Check your `.env` file has correct `OPENAI_API_KEY`
- Verify API key has sufficient credits
- Check logs: `./docker-setup.sh logs`

#### Image upload issues
```bash
# Check storage permissions
docker-compose exec web ls -la /rails/storage
```

### Logs and Debugging
```bash
# View all logs
./docker-setup.sh logs

# View specific service logs
docker-compose logs sidekiq
docker-compose logs redis

# Debug inside container
./docker-setup.sh shell
```

## 🔐 Security Notes

- Never commit `.env` file
- Use strong `SECRET_KEY_BASE`
- Keep OpenAI API key secure
- Run containers as non-root user (production)
- Use Docker secrets for sensitive data in production

## 📈 Performance Tips

- Use Redis for caching and sessions
- Enable jemalloc for memory optimization
- Monitor Sidekiq queue sizes
- Use proper image formats for uploads
- Enable gzip compression (via Thruster)

## 🚢 Deployment

For production deployment, consider:
- Using Docker Swarm or Kubernetes
- External PostgreSQL database
- Redis cluster for high availability
- Load balancing with multiple web containers
- SSL termination at reverse proxy level
- Monitoring with Prometheus/Grafana
