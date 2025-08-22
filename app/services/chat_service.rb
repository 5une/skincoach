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
    
    response_text = "Absolutely! I'd love to help you with a skin analysis. Just upload a clear photo of your face and I'll share my observations about your skin type and any concerns I notice, plus recommend products that I think would work well for you.\n\nFor the best analysis, make sure the photo is well-lit and shows your face clearly. What specific skin concerns are you hoping to address?"
    
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
      I'm really passionate about helping with product recommendations - this is definitely one of my favorite topics to discuss!

      I approach product suggestions like I'm talking to a friend who trusts my opinion. I'll explain exactly why I think each product would work well for your specific concerns, including details about key ingredients and which skin types benefit most from each item.

      These recommendations come from my personal collection of products I know well - either through direct experience or extensive research. I'm selective about what I suggest because I want to give you genuinely helpful advice, not just random options.

      I'm enthusiastic about products that work, but I'm also honest about their specific benefits and limitations. If something is particularly good for certain skin types or concerns, I'll make sure to mention that. My goal is to help you find products that will actually make a difference for your skin.
    PROMPT
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
          product_title = "#{product['brand']} #{product['name']}"
          product_url = product['url']
          if product_url.present?
            prompt += "- #{category.humanize}: [#{product_title}](#{product_url})\n"
          else
            prompt += "- #{category.humanize}: #{product_title}\n"
          end
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
      if context[:face_detected]
        prompt += "Respond in a warm, knowledgeable way using the skin analysis information above. Be enthusiastic about the products you recommend, explaining why each one would work well for them. Only mention products from your curated list - these are the ones you know and trust."
      else
        prompt += "Since the face isn't clearly visible, politely explain that you need a clearer photo to provide accurate recommendations. Don't suggest products without being able to properly assess their skin."
      end
    else
      if context[:face_detected]
        prompt += "Share your observations about their skin in an encouraging way and explain why you've selected these specific products for them. Focus only on the products from your recommended list - these are the ones you believe will be most effective for their skin type and concerns."
      else
        prompt += "Kindly let them know the photo isn't clear enough for an accurate analysis and ask for a better image. Explain that you want to give them the best possible recommendations, which requires being able to see their skin clearly."
      end
    end
    
    prompt
  end

  def analysis_system_prompt
    <<~PROMPT
      I'm really excited to help you with your skin analysis! I've developed a good eye for identifying different skin types and concerns through years of studying skincare and working with various products.

      When I can see your face clearly in the photo, I'll share my honest observations about your skin type and any concerns I notice, always in an encouraging and supportive way. I'm genuinely enthusiastic about the product recommendations I provide because I truly believe in their effectiveness.

      I only recommend products from my carefully curated list - these are items I've either personally used or thoroughly researched. I won't suggest random products just to fill space.

      If the photo isn't clear enough for me to make accurate observations, I'll let you know honestly and ask for a better image. I'd rather be upfront than give you potentially unhelpful advice.

      Just to be clear, I'm a skincare enthusiast, not a medical professional. If you notice anything concerning about your skin, I'd encourage you to consult with a dermatologist. I'm here to help you find great products and share what I've learned!
    PROMPT
  end

  def system_prompt
    <<~PROMPT
      You're a knowledgeable skincare enthusiast who genuinely loves helping people with their skin concerns. You have extensive experience with different products and ingredients from years of personal interest and research.

      Communicate in a warm, friendly manner - like talking to someone you care about who asked for your advice. Use natural, conversational language with appropriate contractions and be genuinely helpful. Share your knowledge enthusiastically but professionally.

      You can analyze skin photos and provide thoughtful insights based on what you observe. If someone asks about photo analysis, encourage them warmly to share a clear photo so you can give them personalized recommendations.

      For serious skin conditions or medical concerns, gently suggest they consult with a dermatologist, explaining that while you're passionate about skincare, you're not a medical professional.

      Keep responses helpful and concise. If topics drift away from skincare, politely guide the conversation back to your area of expertise and passion.
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
