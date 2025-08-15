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

2. **Configure Vision API:**
   
   **Option A: Environment Variables**
   ```bash
   export VISION_PROVIDER=azure  # or 'google'
   export VISION_API_KEY=your_api_key_here
   export VISION_API_ENDPOINT=your_endpoint_here
   export REDIS_URL=redis://localhost:6379/0
   ```

   **Option B: Configuration File**
   ```bash
   cp config/vision_api.yml.example config/vision_api.yml
   # Edit config/vision_api.yml with your credentials
   ```

3. **Start services:**
   ```bash
   # Start Redis (required for Sidekiq)
   redis-server
   
   # Start the application (Rails + Sidekiq + Tailwind CSS)
   bin/dev
   ```

## Vision API Setup

### Azure OpenAI GPT-4o Vision (Recommended)

1. Create Azure OpenAI resource in EU region (for data residency)
2. Deploy GPT-4o model
3. Get API key and endpoint from Azure portal
4. Configure:
   ```bash
   VISION_PROVIDER=azure
   VISION_API_KEY=your_azure_api_key
   VISION_API_ENDPOINT=https://your-resource.openai.azure.com/openai/deployments/gpt-4o/chat/completions?api-version=2024-02-15-preview
   ```

### Google Vertex AI Gemini (Alternative)

1. Create Google Cloud project with Vertex AI enabled
2. Set up service account with Vertex AI permissions
3. Get authentication token
4. Configure:
   ```bash
   VISION_PROVIDER=google
   VISION_API_KEY=your_google_token
   VISION_API_ENDPOINT=https://us-central1-aiplatform.googleapis.com/v1/projects/your-project/locations/us-central1/publishers/google/models/gemini-pro-vision:predict
   ```

## Development Mode

For development without API credentials, use the demo analysis:

```bash
export USE_DEMO_ANALYSIS=true
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
