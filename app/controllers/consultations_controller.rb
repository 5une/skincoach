class ConsultationsController < ApplicationController
  before_action :set_consultation, only: [:show, :status]

  def new
    @consultation = Consultation.new
  end

  def create
    @consultation = Consultation.new(consultation_params)

    if @consultation.save
      # Process image analysis synchronously to avoid cross-dyno file access issues on Heroku
      begin
        # Update status to analyzing
        @consultation.update!(status: "analyzing")
        
        if Rails.env.development? && ENV['USE_DEMO_ANALYSIS'] == 'true'
          # Use demo analysis in development if explicitly enabled
          perform_demo_analysis(@consultation)
        else
          # Use OpenAI vision analysis
          perform_vision_analysis(@consultation)
        end
        
        redirect_to consultation_path(@consultation)
      rescue => e
        Rails.logger.error "Synchronous analysis failed for consultation #{@consultation.id}: #{e.message}"
        @consultation.update!(
          status: "failed",
          error_message: "Analysis failed: #{e.message}"
        )
        redirect_to consultation_path(@consultation), alert: "Analysis failed. Please try again."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # Status page that polls for updates
  end

  def status
    # JSON endpoint for status polling
    respond_to do |format|
      format.json do
        render json: {
          status: @consultation.status,
          html: @consultation.completed? ? render_results_html : nil
        }
      end
    end
  end

  def status_demo
    # Demo status endpoint for testing Stimulus status controller
  end

  private

  def set_consultation
    @consultation = Consultation.find(params[:id])
  end

  def consultation_params
    params.require(:consultation).permit(:photo)
  end

  def render_results_html
    return nil unless @consultation.completed?

    render_to_string(
      partial: 'consultations/results',
      locals: { consultation: @consultation },
      formats: [:html]
    )
  end

  def perform_vision_analysis(consultation)
    # Perform the same analysis as AnalyzeImageJob but synchronously
    unless consultation.photo.attached?
      raise "No photo attached to consultation"
    end

    Rails.logger.info "Starting synchronous vision analysis for consultation #{consultation.id}"

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

    Rails.logger.info "Synchronous analysis completed successfully for consultation #{consultation.id}"
  end

  def perform_demo_analysis(consultation)
    # Simple demo analysis without OpenAI API calls
    sleep(2) # Simulate processing time
    
    demo_analysis = {
      "face_detected" => true,
      "skin_type" => "combination",
      "concerns" => ["mild_acne", "oiliness"],
      "severity" => {
        "mild_acne" => "mild",
        "oiliness" => "moderate"
      },
      "notes" => "Demo analysis completed. Visible combination skin with mild concerns."
    }

    demo_recommendations = {
      "recommended_products" => [
        {
          "name" => "CeraVe Gentle Foaming Cleanser",
          "category" => "cleanser",
          "reason" => "Suitable for combination skin"
        }
      ]
    }

    consultation.update!(
      status: "completed",
      analysis_data: demo_analysis,
      recommendations_data: demo_recommendations
    )
  end
end
