class AnalyzeImageJob < ApplicationJob
  queue_as :default
  
  retry_on VisionAnalysisClient::AnalysisError, wait: :exponentially_longer, attempts: 3
  retry_on RecommendationEngine::RecommendationError, wait: 5.seconds, attempts: 2
  retry_on Net::TimeoutError, wait: 10.seconds, attempts: 2

  def perform(consultation)
    # Update status to analyzing
    consultation.update!(status: 'analyzing')
    
    Rails.logger.info "Starting analysis for consultation #{consultation.id}"
    
    # Step 1: Analyze image with Vision API
    analysis_data = analyze_image_with_vision_api(consultation)
    Rails.logger.info "Vision analysis completed for consultation #{consultation.id}: #{analysis_data}"
    
    # Step 2: Generate product recommendations
    recommendations_data = generate_product_recommendations(analysis_data)
    Rails.logger.info "Recommendations generated for consultation #{consultation.id}"
    
    # Step 3: Save results and mark as completed
    consultation.update!(
      status: 'completed',
      analysis_data: analysis_data,
      recommendations_data: recommendations_data
    )
    
    Rails.logger.info "Analysis completed successfully for consultation #{consultation.id}"
    
  rescue VisionAnalysisClient::AnalysisError => e
    handle_analysis_error(consultation, "Vision analysis failed: #{e.message}", e)
  rescue RecommendationEngine::RecommendationError => e
    handle_analysis_error(consultation, "Recommendation generation failed: #{e.message}", e)
  rescue StandardError => e
    handle_analysis_error(consultation, "Unexpected error during analysis: #{e.message}", e)
  end

  private

  def analyze_image_with_vision_api(consultation)
    unless consultation.photo.attached?
      raise VisionAnalysisClient::AnalysisError, "No photo attached to consultation"
    end
    
    # Initialize vision client
    vision_client = VisionAnalysisClient.new
    
    # Analyze the attached photo
    vision_client.analyze_image(consultation.photo)
  end

  def generate_product_recommendations(analysis_data)
    # Initialize recommendation engine with analysis results
    recommendation_engine = RecommendationEngine.new(analysis_data)
    
    # Generate recommendations
    recommendation_engine.generate_recommendations
  end

  def handle_analysis_error(consultation, message, error = nil)
    Rails.logger.error "Analysis failed for consultation #{consultation.id}: #{message}"
    Rails.logger.error error.backtrace.join("\n") if error&.backtrace
    
    # Update consultation with error
    consultation.update!(
      status: 'failed',
      error_message: message
    )
    
    # Don't re-raise to prevent infinite retries for permanent failures
  end
end