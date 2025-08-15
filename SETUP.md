# AI Dermatology Chatbot - Setup Instructions

## Overview

This Rails 8 application provides AI-powered skin analysis and personalized skincare product recommendations. It uses computer vision APIs to analyze facial photos and recommends products from a curated database.

## Features

- ✅ Image upload with preview (Stimulus JS)
- ✅ Real-time status polling during analysis
- ✅ AI-powered skin analysis via Azure OpenAI GPT-4o Vision or Google Vertex AI Gemini
- ✅ Intelligent product recommendation engine
- ✅ Background job processing with Sidekiq
- ✅ 50+ curated skincare products across 5 categories
- ✅ Mobile-responsive UI with Tailwind CSS

## Prerequisites

- Ruby 3.4.2+
- Rails 8.0+
- SQLite3
- Redis (for Sidekiq)
- Vision API credentials (Azure OpenAI or Google Vertex AI)

## Installation

1. **Clone and setup:**
   ```bash
   git clone <repository>
   cd skin-dermatology-chatbot
   bundle install
   rails db:create db:migrate db:seed
   ```

2. **Configure OpenAI API:**
   
   ```bash
   # Copy the example environment file
   cp env.example .env
   
   # Edit .env with your actual credentials
   nano .env
   ```
   
   Set your OpenAI API key in `.env`:
   ```bash
   OPENAI_API_KEY=your_actual_openai_api_key
   REDIS_URL=redis://localhost:6379/0
   ```

3. **Start services:**
   ```bash
   # Start Redis (required for Sidekiq)
   redis-server
   
   # Start the application (Rails + Sidekiq + Tailwind CSS)
   bin/dev
   ```

## OpenAI API Setup

### Getting Your OpenAI API Key

1. Go to [OpenAI Platform](https://platform.openai.com/account/api-keys)
2. Sign up or log in to your account
3. Create a new API key
4. Copy the API key and add it to your `.env` file:
   ```bash
   OPENAI_API_KEY=sk-your-actual-api-key-here
   ```

**Note**: You'll need access to GPT-4o with vision capabilities. This requires:
- An OpenAI account with API access
- Sufficient credits for GPT-4o usage
- Vision API access (usually included with GPT-4o)

## Development Mode

For development without API credentials, set this in your `.env` file:

```bash
USE_DEMO_ANALYSIS=true
```

Then start the app:
```bash
bin/dev
```

This will use `AnalyzeImageDemoJob` which simulates the analysis process with sample data.

## Usage

1. **Upload Photo**: Visit `http://localhost:3000` and upload a clear facial photo
2. **Analysis**: The system analyzes skin type and concerns using AI
3. **Recommendations**: Get personalized product recommendations
4. **Monitor**: Check Sidekiq at `http://localhost:3000/sidekiq` for job status

## Architecture

### Services Layer

- **VisionAnalysisClient**: Handles API calls to Azure OpenAI or Google Vertex AI
- **RecommendationEngine**: Maps skin concerns to products with intelligent filtering

### Background Jobs

- **AnalyzeImageJob**: Real vision API analysis
- **AnalyzeImageDemoJob**: Demo analysis for development

### Models

- **Product**: Skincare products with categories, ingredients, and concern tags
- **Consultation**: User sessions with photo upload and analysis results

### Safety Features

- Non-comedogenic filtering for acne-prone skin
- Fragrance-free options for sensitive skin
- Ingredient-based recommendations (niacinamide for redness, etc.)
- Medical disclaimers and dermatologist recommendations

## Database

The app comes pre-seeded with 50+ products across categories:
- **Cleansers**: 10 products
- **Serums**: 12 products  
- **Moisturizers**: 10 products
- **Sunscreens**: 9 products
- **Spot Treatments**: 9 products

## Security & Privacy

- EU data residency options available (Azure EU regions)
- Photos processed but not permanently stored
- No personal data collection beyond uploaded image
- Rate limiting and error handling built-in

## API Response Format

The vision API returns structured JSON:

```json
{
  "skin_type": "combination",
  "concerns": ["acne", "oiliness"],
  "severity": {
    "acne": "mild",
    "oiliness": "moderate"
  },
  "notes": "Brief neutral observations without medical diagnosis"
}
```

## Troubleshooting

- **Vision API errors**: Check credentials and endpoint URLs
- **Sidekiq not processing**: Ensure Redis is running
- **No product recommendations**: Check product database seeding
- **Upload failures**: Verify Active Storage configuration

## Production Deployment

1. Set up proper Redis instance
2. Configure vision API with production credentials
3. Set up background job monitoring
4. Enable SSL for secure image uploads
5. Configure proper logging and error tracking

## Contributing

This is an MVP implementation. Future enhancements could include:
- Real-time product pricing via retailer APIs
- Advanced ingredient analysis
- User account management
- Product review integration
- Multi-language support
