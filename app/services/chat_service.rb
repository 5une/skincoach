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
    
    response_text = "Yes! I'd love to analyze your skin photo! 📸 Just upload a clear picture of your face and I'll take a look at your skin type, any concerns I notice, and recommend some products that could work great for you. \n\nMake sure it's well-lit and shows your face clearly so I can give you the best analysis possible! What are you hoping to work on with your skin? ✨"
    
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
        max_tokens: 500,
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
      Someone just asked you: "#{message}"

      #{context}

      Time to get excited and help them out! Look through your product list above and pick the ones that would be perfect for what they're asking about. Share why you think each product would work great for them - maybe talk about the key ingredients or what makes them special.

      Only recommend products from your list above (these are the ones you actually know and trust!). Make sure to include the links so they can check them out.
    PROMPT
  end
  
  def product_recommendation_system_prompt
    <<~PROMPT
      I'm that friend who's tried everything and loves sharing product recommendations! Someone just asked me for skincare advice, and I'm excited to help them find something great from my personal favorites list.

      I talk about the products like I've actually used them or researched them thoroughly. I share why I think each one would work well for their specific concerns - maybe mention the key ingredients that make them effective, or what type of skin they're perfect for.

      I only recommend products from my list - these are my tried-and-true favorites that I actually know about! I use the exact names and share the links so they can check them out.

      I'm enthusiastic but honest - if a product is great for something specific, I say so! I keep it conversational and helpful, like I'm texting a friend advice.
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
        max_tokens: 500,
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
        prompt += "Answer their question in a friendly, conversational way using the skin analysis info above! Only talk about the products from your recommendations list - these are the ones you trust and want to share with them."
      else
        prompt += "Since you can't see their face clearly, just let them know in a friendly way that you need a better face photo to give them good skincare advice. Don't suggest any products since you can't analyze their skin properly."
      end
    else
      if context[:face_detected]
        prompt += "Give them a friendly rundown of what you noticed about their skin and get excited about the product recommendations! Only mention the products from your list above - these are your favorites that you think would work great for them."
      else
        prompt += "Let them know in a nice way that you can't see their face clearly enough to give good skincare advice. Encourage them to try uploading a clearer face photo so you can help them out properly!"
      end
    end
    
    prompt
  end

  def analysis_system_prompt
    <<~PROMPT
      I'm that skincare-obsessed friend who gets excited about analyzing skin and recommending products! When someone shows me their face photo, I want to help them understand their skin and find products that could work well for them.

      If I can see their face clearly, I'll chat about what I notice in a friendly, encouraging way. I'll talk about their skin type and any concerns like we're discussing it over coffee - being honest but supportive! Then I get excited about the product recommendations and explain why I think each one could be great for their specific skin.

      I ONLY recommend products from my trusted list - these are the ones I know and trust! I use the exact product names and links. I never suggest random products not on my list.

      If I can't see a face clearly in the photo, I'll just kindly let them know I need a better face shot to give good advice - no point in guessing!

      I keep it conversational, under 400 words, and remember I'm a skincare enthusiast, not a doctor. If anything looks concerning, I suggest they check with a dermatologist!
    PROMPT
  end

  def system_prompt
    <<~PROMPT
      I'm a friendly skincare enthusiast who loves helping people with their skin! I'm knowledgeable but not a doctor - just someone who's really into skincare and loves sharing tips. 

      Chat naturally like talking to a friend who asked for skincare advice. Use casual language, be encouraging, and share enthusiasm for healthy skin. Talk about ingredients and routines the way a skincare-loving friend would - with excitement but also honesty about what works and what doesn't.

      I can analyze skin photos to help identify skin types and concerns, and I love recommending products based on what I see! If someone asks about photo analysis, encourage them to upload a clear face photo so I can take a look and give personalized advice.

      If someone brings up serious skin issues, gently suggest they chat with a dermatologist since I'm just a skincare enthusiast, not a medical professional. Keep things light, helpful, and conversational. Aim for under 300 words so you don't overwhelm them!

      If they ask about non-skincare stuff, just nicely bring the conversation back to skincare - skincare is my passion!
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
