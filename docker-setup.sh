#!/bin/bash

# Docker Setup Script for Skin Dermatology Chatbot
set -e

echo "🚀 Setting up Docker environment for Skin Dermatology Chatbot"

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    if [ -f env.example ]; then
        cp env.example .env
        echo "✅ .env file created. Please edit it with your actual values:"
        echo "   - OPENAI_API_KEY=your_openai_api_key"
        echo "   - SECRET_KEY_BASE=generate_with_rails_secret"
        echo "   - RAILS_MASTER_KEY=from_config/master.key"
    else
        echo "❌ env.example not found. Please create .env manually."
        exit 1
    fi
fi

# Function to show available commands
show_help() {
    echo ""
    echo "📚 Available commands:"
    echo "  dev     - Start development environment"
    echo "  prod    - Start production environment"
    echo "  build   - Build all Docker images"
    echo "  clean   - Clean up Docker containers and images"
    echo "  logs    - Show application logs"
    echo "  shell   - Open shell in web container"
    echo "  setup   - Run database setup"
    echo ""
}

# Parse command line arguments
case "${1:-help}" in
    "dev"|"development")
        echo "🔧 Starting development environment..."
        docker-compose -f docker-compose.dev.yml up --build -d
        echo "✅ Development environment started!"
        echo "   Web: http://localhost:3000"
        echo "   Redis: localhost:6379"
        echo "   PostgreSQL: localhost:5432"
        ;;
    
    "prod"|"production")
        echo "🏭 Starting production environment..."
        docker-compose up --build -d
        echo "✅ Production environment started!"
        echo "   Web: http://localhost:3000"
        ;;
    
    "build")
        echo "🔨 Building Docker images..."
        docker-compose -f docker-compose.dev.yml build
        docker-compose build
        echo "✅ All images built successfully!"
        ;;
    
    "clean")
        echo "🧹 Cleaning up Docker containers and images..."
        docker-compose -f docker-compose.dev.yml down -v
        docker-compose down -v
        docker system prune -f
        echo "✅ Cleanup completed!"
        ;;
    
    "logs")
        if [ "${2}" = "dev" ]; then
            docker-compose -f docker-compose.dev.yml logs -f
        else
            docker-compose logs -f
        fi
        ;;
    
    "shell")
        if [ "${2}" = "dev" ]; then
            docker-compose -f docker-compose.dev.yml exec web bash
        else
            docker-compose exec web bash
        fi
        ;;
    
    "setup")
        echo "🗄️ Setting up database..."
        if [ "${2}" = "dev" ]; then
            docker-compose -f docker-compose.dev.yml exec web rails db:create db:migrate db:seed
        else
            docker-compose exec web rails db:prepare db:seed
        fi
        echo "✅ Database setup completed!"
        ;;
    
    "help"|*)
        echo "🐳 Docker Setup for Skin Dermatology Chatbot"
        show_help
        ;;
esac
