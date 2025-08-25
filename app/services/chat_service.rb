class ChatService
  class ChatError < StandardError; end

  def initialize
    @api_key = ENV["OPENAI_API_KEY"]
    raise ChatError, "OpenAI API key missing" if @api_key.blank?

    @client = OpenAI::Client.new(access_token: @api_key)
  end

    def respond_to_skin_question(message)
    Rails.logger.info "Processing skin question: #{message[0..100]}..."

    # Check if user is asking about photo analysis first
    if asking_about_photo_analysis?(message)
      Rails.logger.info "Detected photo analysis question"
      return respond_about_photo_capabilities(message)
    end

    # Check if user is asking for product recommendations
    if asking_for_product_recommendations?(message)
      Rails.logger.info "Detected product recommendation request"
      return respond_with_product_recommendations(message)
    end
    
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
        max_tokens: 400,
        temperature: 0.1
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

      # Step 2: Generate initial conversational response (no product recommendations yet)
      conversation_response = generate_initial_analysis_response(analysis_data, message_text)
      Rails.logger.info "Initial conversational response generated"

      {
        message: conversation_response,
        analysis: analysis_data,
        recommendations: nil # No recommendations on first photo upload
      }
    rescue VisionAnalysisClient::AnalysisError => e
      Rails.logger.error "Analysis service error: #{e.message}"
      raise ChatError, "Photo analysis failed: #{e.message}"
    rescue => e
      Rails.logger.error "Photo analysis error: #{e.message}"
      raise ChatError, "Failed to analyze photo: #{e.message}"
    end
  end

  private

  def asking_about_photo_analysis?(message)
    message_lower = message.downcase
    
    # Check for photo analysis keywords
    photo_keywords = [
      'analyze photo', 'analyze my photo', 'analyze picture', 'analyze my picture',
      'look at photo', 'look at my photo', 'look at picture', 'look at my picture',
      'check photo', 'check my photo', 'check picture', 'check my picture',
      'analyze my skin', 'analyze skin', 'photo analysis', 'picture analysis',
      'upload photo', 'upload picture', 'send photo', 'send picture',
      'can you analyze', 'can you look at', 'can you check'
    ]
    
    photo_keywords.any? { |keyword| message_lower.include?(keyword) }
  end

  def respond_about_photo_capabilities(message)
    Rails.logger.info "Responding about photo analysis capabilities"
    
    response_text = "Absolutely! I'd love to do a skin consultation for you - this is exactly what I do every day at my clinic! Just upload a clear photo of your face and I'll analyze your skin type and any concerns I notice, then recommend some products from my professional collection that I think would work perfectly for you.\n\nFor the best analysis, make sure the photo is well-lit and shows your face clearly. I'm really excited to help - what specific skin goals are you hoping to work on?"
    
    {
      message: response_text,
      analysis: nil,
      recommendations: nil
    }
  end

  def asking_for_product_recommendations?(message)
    message_lower = message.downcase
    
    # Check for product recommendation keywords
    recommendation_keywords = [
      'recommend', 'suggest', 'what should i use', 'what to use', 'what can i use',
      'best product', 'good product', 'help me find', 'what product',
      'for acne', 'for dry skin', 'for oily skin', 'for sensitive skin',
      'for redness', 'for hyperpigmentation', 'for wrinkles', 'for aging'
    ]
    
    recommendation_keywords.any? { |keyword| message_lower.include?(keyword) }
  end
  
  def respond_with_product_recommendations(message)
    Rails.logger.info "Generating product recommendations for query: #{message}"
    
    # Extract skin concerns and product types from the message
    concerns = extract_skin_concerns(message)
    categories = extract_product_categories(message)
    
    # Query products from database
    products = find_relevant_products(concerns, categories)
    
    if products.any?
      # Generate AI response with product recommendations
      generate_product_recommendation_response(message, products)
    else
      # Fallback response when no products found
      {
        message: "I'd love to help you find the right products! Could you be more specific about your skin concerns or the type of product you're looking for? For example, you could ask about cleansers for acne-prone skin or moisturizers for dry skin.",
        analysis: nil,
        recommendations: nil
      }
    end
  end
  
  def extract_skin_concerns(message)
    message_lower = message.downcase
    concerns = []
    
    # Map keywords to database skin concerns
    concern_mapping = {
      'acne' => 'acne',
      'pimple' => 'acne',
      'breakout' => 'acne',
      'zit' => 'acne',
      'dry' => 'dryness',
      'dehydrated' => 'dryness',
      'flaky' => 'dryness',
      'oily' => 'oiliness',
      'greasy' => 'oiliness',
      'shiny' => 'oiliness',
      'red' => 'redness',
      'irritated' => 'redness',
      'inflamed' => 'redness',
      'sensitive' => 'sensitivity',
      'reactive' => 'sensitivity',
      'dark spot' => 'hyperpigmentation',
      'pigmentation' => 'hyperpigmentation',
      'discoloration' => 'hyperpigmentation'
    }
    
    concern_mapping.each do |keyword, concern|
      concerns << concern if message_lower.include?(keyword)
    end
    
    concerns.uniq
  end
  
  def extract_product_categories(message)
    message_lower = message.downcase
    categories = []
    
    # Map keywords to database categories
    category_mapping = {
      'cleanser' => 'cleanser',
      'cleansing' => 'cleanser',
      'wash' => 'cleanser',
      'face wash' => 'cleanser',
      'serum' => 'serum',
      'treatment' => 'serum',
      'moisturizer' => 'moisturizer',
      'moisturiser' => 'moisturizer',
      'cream' => 'moisturizer',
      'lotion' => 'moisturizer',
      'sunscreen' => 'sunscreen',
      'spf' => 'sunscreen',
      'sun protection' => 'sunscreen',
      'spot treatment' => 'spot_treatment'
    }
    
    category_mapping.each do |keyword, category|
      categories << category if message_lower.include?(keyword)
    end
    
    categories.uniq
  end
  
  def find_relevant_products(concerns, categories)
    products = Product.all
    
    # Filter by categories if specified
    if categories.any?
      products = products.where(category: categories)
    end
    
    # Filter by concerns if specified
    if concerns.any?
      concern_query = concerns.map { |c| "skin_concerns ILIKE ?" }.join(" OR ")
      concern_values = concerns.map { |c| "%#{c}%" }
      products = products.where(concern_query, *concern_values)
    end
    
    # Limit results and order by name
    products.limit(6).order(:category, :name)
  end
  
  def generate_product_recommendation_response(message, products)
    # Group products by category for better organization
    products_by_category = products.group_by(&:category)
    
    # Build context for AI
    context = build_product_context(products_by_category)
    prompt = build_product_recommendation_prompt(message, context)
    
    # Generate AI response
    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: product_recommendation_system_prompt },
          { role: "user", content: prompt }
        ],
        max_tokens: 300,
        temperature: 0.1
      }
    )
    
    content = response.dig("choices", 0, "message", "content")
    raise ChatError, "No product recommendation response received" if content.blank?
    
    message_response = apply_safety_checks(content)
    
    {
      message: message_response,
      analysis: nil,
      recommendations: { picks: products_by_category }
    }
  end
  
  def build_product_context(products_by_category)
    context = "AVAILABLE PRODUCTS FROM OUR DATABASE:\n\n"
    
    products_by_category.each do |category, products|
      context += "#{category.upcase.tr('_', ' ')}:\n"
      products.each do |product|
        context += "- [#{product.brand} #{product.name}](#{product.product_url})"
        context += " - $#{product.price}" if product.price.present?
        context += " - For: #{product.skin_concerns}" if product.skin_concerns.present?
        context += " - Ingredients: #{product.key_ingredients}" if product.key_ingredients.present?
        context += "\n"
      end
      context += "\n"
    end
    
    context
  end
  
  def build_product_recommendation_prompt(message, context)
    <<~PROMPT
      Someone asked you: "#{message}"

      #{context}

      This is exactly the kind of question you love helping with! Look through your product list above and select the ones that would be most suitable for their specific concerns. Explain why you think each product would work well for them, including details about key ingredients and which skin types benefit most.

      Only recommend products from your curated list above - these are the ones you know well and trust. Make sure to include the product links so they can learn more about each item.
    PROMPT
  end
  
  def product_recommendation_system_prompt
    <<~PROMPT
      When suggesting skincare products, focus on generic product types rather than specific brands.

      Recommend things like "gentle cleanser," "hydrating serum," "sunscreen," or "moisturizer for sensitive skin." Explain briefly what each type of product does and why it might help with their specific concerns.

      Don't include product links or recommend specific branded products from any database.

      Keep recommendations simple and focused on product categories that address their skin needs.

      Only suggest products after you've had a proper conversation and understand their situation better. Don't jump straight into recommendations.

      Your tone should be helpful but measured - less enthusiasm, more practical guidance.
    PROMPT
  end

  def generate_initial_analysis_response(analysis_data, user_message)
    # Build simple context for initial response (no recommendations)
    context = build_simple_analysis_context(analysis_data)
    
    # Create prompt for initial photo reaction
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
        max_tokens: 300,
        temperature: 0.3
      }
    )

    content = response.dig("choices", 0, "message", "content")
    raise ChatError, "No analysis response content received" if content.blank?

    # Apply safety checks
    apply_safety_checks(content)
  end

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
        max_tokens: 300,
        temperature: 0
      }
    )

    content = response.dig("choices", 0, "message", "content")
    raise ChatError, "No analysis response content received" if content.blank?

    apply_safety_checks(content)
  end

  def build_simple_analysis_context(analysis_data)
    # Extract basic analysis information without recommendations
    face_detected = analysis_data.dig('face_detected') || false
    skin_type = analysis_data.dig('skin_assessment', 'overall_skin_type') || 'unknown'
    concerns = analysis_data.dig('skin_assessment', 'specific_concerns') || []
    
    {
      face_detected: face_detected,
      skin_type: skin_type,
      concerns: concerns
    }
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
    if context[:face_detected]
      concerns_list = context[:concerns].any? ? context[:concerns].join(', ') : "no major concerns"
      
      prompt = <<~PROMPT
        You just looked at their photo. Here's what you observed:
        - Skin type: #{context[:skin_type]}
        - What you can see: #{concerns_list}
        
        Give a brief, natural reaction to what you see. Just mention the main things you notice in a casual way.
        
        Then ask a follow-up question about their experience - like how long they've had these concerns, their current routine, or what they've tried before.
        
        Don't recommend any specific products yet. This is just the beginning of getting to know their skin.
        
        Keep it conversational and brief.
      PROMPT
    else
      prompt = <<~PROMPT
        No clear facial skin was detected in the photo.
        
        Let them know you'd like to help but need a clearer photo that shows their face. Keep it natural and brief.
        
        Don't recommend any products since you can't see their skin properly.
      PROMPT
    end
    
    prompt
  end

  def analysis_system_prompt
    <<~PROMPT
      You're Emma, a skincare specialist. When someone shares a photo, your role is to give a brief, honest observation and then engage in conversation to understand their experience better.

      Keep your initial photo reaction short and natural - just mention what you can see without going into detail. For example: "I can see some redness and a few breakouts" or "Your skin looks pretty clear overall, though I notice some dryness."

      After your brief observation, ask a follow-up question about their experience - how long they've had these concerns, what their current routine is like, what they've tried before, etc.

      Don't immediately jump into product recommendations. The goal is to have a natural conversation first to understand their situation better.

      Use natural, varied language. Don't follow the same pattern every time. Sometimes be more direct, sometimes softer in your approach.

      Only mention seeing a dermatologist if you notice something that looks serious or unusual.
    PROMPT
  end

  def system_prompt
    <<~PROMPT
      You're Emma, a skincare specialist with experience helping people with their skin concerns. You communicate naturally and calmly, like talking to someone you care about.

      Your approach is to have genuine conversations about skin concerns rather than immediately jumping to product recommendations. You ask follow-up questions to understand the situation better before suggesting anything.

      When someone shares a photo, you give a brief, honest observation of what you see, then ask questions about their experience - how long they've had certain concerns, what they've tried before, their routine, etc.

      You only suggest specific product types (like "gentle cleanser" or "hydrating serum") after you've had a proper conversation and understand their needs. You don't recommend specific branded products or include product links.

      Your tone is neutral and empathetic without being overly enthusiastic. You're helpful and knowledgeable but speak in a measured, caring way.

      For serious skin conditions, you suggest seeing a dermatologist since that's beyond your scope.

      Keep responses natural and conversational, not procedural. Vary your language and don't follow strict patterns.
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
