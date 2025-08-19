class ChatService
  class ChatError < StandardError; end

  def initialize
    @api_key = ENV["OPENAI_API_KEY"]
    raise ChatError, "OpenAI API key missing" if @api_key.blank?

    @client = OpenAI::Client.new(access_token: @api_key)
  end

  def respond_to_skin_question(message)
    Rails.logger.info "Processing skin question: #{message[0..100]}..."
    
    # Build the chat completion request
    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: system_prompt
          },
          {
            role: "user",
            content: message
          }
        ],
        max_tokens: 500,
        temperature: 0.3
      }
    )

    # Extract and validate response
    content = response.dig("choices", 0, "message", "content")
    raise ChatError, "No response content received" if content.blank?

    Rails.logger.info "Chat response generated successfully"
    
    # Apply safety checks and return structured response
    message_response = apply_safety_checks(content)
    
    {
      message: message_response,
      analysis: nil,
      recommendations: nil
    }
  rescue => e
    Rails.logger.error "Chat service error: #{e.message}"
    raise ChatError, "Failed to generate response: #{e.message}"
  end

  def respond_with_photo_analysis(message_text, photo)
    Rails.logger.info "Processing photo analysis with optional message: #{message_text&.[](0..50)}..."
    
    begin
      # Step 1: Analyze the photo using VisionAnalysisClient
      vision_client = VisionAnalysisClient.new
      analysis_data = vision_client.analyze_image(photo)
      Rails.logger.info "Vision analysis completed"

      # Step 2: Generate AI recommendations using AiRecommendationEngine
      ai_engine = AiRecommendationEngine.new(analysis_data)
      recommendations_data = ai_engine.generate_recommendations
      Rails.logger.info "AI recommendations generated"

      # Step 3: Generate conversational response based on analysis and message
      conversation_response = generate_analysis_response(analysis_data, recommendations_data, message_text)
      Rails.logger.info "Conversational response generated"

      {
        message: conversation_response,
        analysis: analysis_data,
        recommendations: recommendations_data
      }
    rescue VisionAnalysisClient::AnalysisError, AiRecommendationEngine::RecommendationError => e
      Rails.logger.error "Analysis service error: #{e.message}"
      raise ChatError, "Photo analysis failed: #{e.message}"
    rescue => e
      Rails.logger.error "Photo analysis error: #{e.message}"
      raise ChatError, "Failed to analyze photo: #{e.message}"
    end
  end

  private

  def generate_analysis_response(analysis_data, recommendations_data, user_message)
    # Build context from analysis results
    context = build_analysis_context(analysis_data, recommendations_data)
    
    # Create prompt that includes analysis context
    prompt = build_analysis_response_prompt(context, user_message)
    
    # Generate conversational response
    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: analysis_system_prompt
          },
          {
            role: "user", 
            content: prompt
          }
        ],
        max_tokens: 600,
        temperature: 0.3
      }
    )

    content = response.dig("choices", 0, "message", "content")
    raise ChatError, "No analysis response content received" if content.blank?

    apply_safety_checks(content)
  end

  def build_analysis_context(analysis_data, recommendations_data)
    face_detected = analysis_data["face_detected"]
    skin_type = analysis_data["skin_type"]
    concerns = Array(analysis_data["concerns"])
    severity = analysis_data["severity"] || {}
    notes = analysis_data["notes"]
    
    # Extract top recommendations by category
    top_products = {}
    recommendations_data[:picks]&.each do |category, products|
      top_products[category] = products.first if products.any?
    end
    
    {
      face_detected: face_detected,
      skin_type: skin_type,
      concerns: concerns,
      severity: severity,
      notes: notes,
      recommendations: top_products,
      rationale: recommendations_data[:rationale]
    }
  end

  def build_analysis_response_prompt(context, user_message)
    prompt = "Based on the skin analysis results:\n\n"
    
    if context[:face_detected]
      prompt += "SKIN ANALYSIS:\n"
      prompt += "- Skin Type: #{context[:skin_type]}\n"
      
      if context[:concerns].any?
        concerns_with_severity = context[:concerns].map do |concern|
          severity = context[:severity][concern] || "mild"
          "#{concern} (#{severity})"
        end
        prompt += "- Concerns: #{concerns_with_severity.join(', ')}\n"
      else
        prompt += "- Concerns: None detected\n"
      end
      
      prompt += "- Notes: #{context[:notes]}\n\n"
      
      if context[:recommendations].any?
        prompt += "TOP PRODUCT RECOMMENDATIONS:\n"
        context[:recommendations].each do |category, product|
          prompt += "- #{category.humanize}: #{product['brand']} #{product['name']}\n"
        end
        prompt += "\n"
      end
      
      if context[:rationale].present?
        prompt += "RECOMMENDATION RATIONALE:\n#{context[:rationale]}\n\n"
      end
    else
      prompt += "No facial skin was detected in the uploaded image. "
      prompt += "Please upload a clear photo of your face for skin analysis.\n\n"
    end
    
    if user_message.present?
      prompt += "USER QUESTION: #{user_message}\n\n"
      prompt += "Please provide a helpful response that addresses their question while incorporating the skin analysis results above."
    else
      prompt += "Please provide a friendly summary of the skin analysis and personalized skincare advice based on the results."
    end
    
    prompt
  end

  def analysis_system_prompt
    <<~PROMPT
      You are a helpful skincare assistant providing personalized advice based on skin analysis results. Your role is to:

      1. Explain skin analysis results in a friendly, conversational way
      2. Connect the analysis to practical skincare advice
      3. Highlight relevant product recommendations and explain why they're suitable
      4. Answer any specific questions the user has about their skin or skincare
      5. Provide encouraging and supportive guidance

      GUIDELINES:
      - Be conversational and friendly, not clinical
      - Focus on practical skincare tips and product usage
      - Explain why certain products are recommended for their specific skin type/concerns
      - If no face was detected, guide them on how to take a better photo
      - Always emphasize that this is for cosmetic skincare purposes
      - Recommend professional consultation for serious concerns
      - Keep responses concise but informative (under 500 words)

      SAFETY RULES:
      - This is cosmetic skincare advice, not medical diagnosis
      - Never diagnose medical conditions
      - Always suggest dermatologist consultation for concerning symptoms
      - Focus on general skincare education and product guidance

      Respond in a warm, helpful tone as if you're a knowledgeable friend giving skincare advice.
    PROMPT
  end

  def system_prompt
    <<~PROMPT
      You are a helpful skincare assistant chatbot. Your role is to:

      1. Answer general questions about skincare, skin types, and common skin concerns
      2. Provide educational information about skincare ingredients and routines
      3. Suggest general skincare tips and best practices
      4. Help users understand different skin conditions (acne, dryness, sensitivity, etc.)
      5. Recommend when to see a dermatologist for serious concerns

      IMPORTANT GUIDELINES:
      - You are NOT a doctor and cannot provide medical diagnoses
      - Always recommend consulting a dermatologist for serious or persistent skin issues
      - Focus on general skincare education and cosmetic concerns
      - Be helpful, friendly, and informative
      - Keep responses concise (under 400 words)
      - If asked about non-skincare topics, politely redirect to skincare

      SAFETY RULES:
      - Never diagnose medical conditions
      - Don't recommend prescription medications
      - Always suggest professional consultation for concerning symptoms
      - Focus on cosmetic skincare rather than medical treatment

      Respond in a conversational, helpful tone. If you're unsure about something, say so and recommend professional consultation.
    PROMPT
  end

  def apply_safety_checks(content)
    # Check for medical diagnosis language
    medical_terms = %w[
      diagnose diagnosis disease disorder syndrome condition
      pathology pathological treatment therapy cure
      prescription medication drug infection cancer
      melanoma carcinoma lesion biopsy
    ]

    content_lower = content.downcase
    found_terms = medical_terms.select { |term| content_lower.include?(term) }

    if found_terms.any?
      Rails.logger.warn "Medical terminology detected in chat response: #{found_terms.join(', ')}"
      
      # Add disclaimer if medical terms are detected
      content += "\n\n⚠️ Important: This is general skincare information only. For medical concerns, please consult a qualified dermatologist or healthcare provider."
    end

    # Check response length and truncate if needed
    words = content.split
    if words.length > 400
      content = words.first(400).join(" ") + "..."
      Rails.logger.info "Truncated chat response to 400 words"
    end

    content
  end
end
