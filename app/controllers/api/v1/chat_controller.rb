class Api::V1::ChatController < ApplicationController
  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token
  
  # Enable CORS for widget usage
  before_action :set_cors_headers
  
  # Handle chat messages about skin concerns (text and/or photo)
  def message
    message_text = params[:message]
    photo = params[:photo]
    
    # At least one input is required
    if message_text.blank? && photo.blank?
      render json: { error: "Message or photo is required" }, status: :bad_request
      return
    end
    
    begin
      chat_service = ChatService.new
      
      # Handle photo analysis if photo is provided
      if photo.present?
        Rails.logger.info "Processing chat message with photo analysis"
        response = chat_service.respond_with_photo_analysis(message_text, photo)
      else
        Rails.logger.info "Processing text-only chat message"
        response = chat_service.respond_to_skin_question(message_text)
      end
      
      render json: {
        status: "success",
        response: response[:message],
        analysis: response[:analysis],
        recommendations: response[:recommendations],
        timestamp: Time.current
      }
    rescue => e
      Rails.logger.error "Chat API error: #{e.message}"
      render json: { 
        error: "Failed to process message", 
        details: e.message 
      }, status: :internal_server_error
    end
  end
  
  # Handle photo analysis with recommendations
  def analyze_photo
    photo = params[:photo]
    
    if photo.blank?
      render json: { error: "Photo is required" }, status: :bad_request
      return
    end
    
    begin
      # Create a temporary consultation for API usage
      consultation = Consultation.create!(status: "pending")
      consultation.photo.attach(photo)
      consultation.update!(status: "analyzing")
      
      # Perform synchronous analysis
      perform_vision_analysis(consultation)
      
      render json: {
        status: "success",
        consultation_id: consultation.id,
        analysis: consultation.analysis_data,
        recommendations: consultation.recommendations_data,
        timestamp: Time.current
      }
    rescue => e
      Rails.logger.error "Photo analysis API error: #{e.message}"
      render json: { 
        error: "Failed to analyze photo", 
        details: e.message 
      }, status: :internal_server_error
    end
  end
  
  # Get consultation status and results
  def consultation_status
    consultation_id = params[:id]
    
    begin
      consultation = Consultation.find(consultation_id)
      
      render json: {
        status: consultation.status,
        analysis: consultation.analysis_data,
        recommendations: consultation.recommendations_data,
        error_message: consultation.error_message,
        timestamp: Time.current
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Consultation not found" }, status: :not_found
    rescue => e
      Rails.logger.error "Consultation status API error: #{e.message}"
      render json: { 
        error: "Failed to get consultation status", 
        details: e.message 
      }, status: :internal_server_error
    end
  end
  
  # Handle CORS preflight requests
  def options
    head :ok
  end

  # Get product recommendations by category or concern
  def products
    category = params[:category]
    concern = params[:concern]
    limit = params[:limit]&.to_i || 10
    
    begin
      products = Product.all
      
      if category.present?
        products = products.where(category: category)
      end
      
      if concern.present?
        # Simple text search in key_ingredients and skin_concerns
        products = products.where(
          "key_ingredients ILIKE ? OR skin_concerns ILIKE ?", 
          "%#{concern}%", "%#{concern}%"
        )
      end
      
      products = products.limit(limit)
      
      render json: {
        status: "success",
        products: products.map do |product|
          {
            id: product.id,
            name: product.name,
            brand: product.brand,
            category: product.category,
            price: product.price,
            currency: product.currency,
            product_url: product.product_url,
            image_url: product.image_url,
            comedogenic_rating: product.comedogenic_rating,
            key_ingredients: product.key_ingredients,
            skin_concerns: product.skin_concerns
          }
        end,
        total_count: products.count,
        timestamp: Time.current
      }
    rescue => e
      Rails.logger.error "Products API error: #{e.message}"
      render json: { 
        error: "Failed to get products", 
        details: e.message 
      }, status: :internal_server_error
    end
  end
  
  private
  
  def set_cors_headers
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
  end
  
  def perform_vision_analysis(consultation)
    # Reuse the same analysis logic from ConsultationsController
    unless consultation.photo.attached?
      raise "No photo attached to consultation"
    end

    Rails.logger.info "Starting API vision analysis for consultation #{consultation.id}"

    # Step 1: Analyze image with Vision API
    vision_client = VisionAnalysisClient.new
    analysis_data = vision_client.analyze_image(consultation.photo)
    Rails.logger.info "Vision analysis completed for consultation #{consultation.id}"

    # Step 2: Generate product recommendations
    ai_recommendation_engine = AiRecommendationEngine.new(analysis_data)
    recommendations_data = ai_recommendation_engine.generate_recommendations
    Rails.logger.info "Recommendations generated for consultation #{consultation.id}"

    # Step 3: Save results and mark as completed
    consultation.update!(
      status: "completed",
      analysis_data: analysis_data,
      recommendations_data: recommendations_data
    )

    Rails.logger.info "API analysis completed successfully for consultation #{consultation.id}"
  end
end
