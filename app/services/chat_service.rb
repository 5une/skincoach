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
    
    # Apply safety checks
    apply_safety_checks(content)
  rescue => e
    Rails.logger.error "Chat service error: #{e.message}"
    raise ChatError, "Failed to generate response: #{e.message}"
  end

  private

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
