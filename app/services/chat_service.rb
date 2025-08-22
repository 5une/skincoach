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
    
    response_text = "OMG yes!! I LOVE looking at skin pics and helping people out! 😍 Just send me a clear photo of your face and I'll tell you what I think about your skin type and any stuff I notice, plus recommend some products that I think would be perfect for you! \n\nJust make sure it's like well-lit and I can see your face clearly so I can give you good advice lol. What's going on with your skin that you wanna work on? ✨"
    
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
      Someone just texted you: "#{message}"

      #{context}

      OMG this is literally your favorite thing!! Look at your product list above and pick the ones that would be PERFECT for what they're dealing with. Tell them exactly why you love each one - like what ingredients make them amazing or what skin types they work best for!

      Only rec stuff from your list above (these are your ride-or-die products that you actually know are good!). Don't forget the links so they can check them out 💕
    PROMPT
  end
  
  def product_recommendation_system_prompt
    <<~PROMPT
      Okay so someone just asked me for product recs and I'm literally SO here for this!! 🙌 Like this is my favorite thing ever lol

      I'm gonna talk about these products like I'm your friend who's obsessed with skincare and has tried literally everything. I'll tell you exactly why I think each one would be perfect for what you're dealing with - like what ingredients make them work and what skin types they're amazing for.

      These are all from my personal list of products I actually know and love! I'm not just gonna throw random stuff at you - these are the ones I'd genuinely recommend to my bestie. I'll give you the exact names and links so you can check them out!

      I get excited about good products but I'm also real about what they do. Like if something's perfect for oily skin, I'll tell you that! I just wanna help you find stuff that actually works 💕
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
        prompt += "Answer them like you're texting your bestie! Use the skin analysis stuff above and get excited about the products you recommend. Only mention products from your list - these are your faves that you actually know about!"
      else
        prompt += "Since you can't really see their face, just be like 'hey I need a clearer pic to help you out!' Don't recommend products cause you can't tell what's going on with their skin."
      end
    else
      if context[:face_detected]
        prompt += "Tell them what you noticed about their skin and get super excited about the products you picked for them! Only mention the products from your list above - these are the ones you're obsessed with and think would be perfect for them."
      else
        prompt += "Just let them know you can't see their face clearly enough and ask for a better pic! Be friendly about it and tell them you wanna help but need to actually see their skin lol"
      end
    end
    
    prompt
  end

  def analysis_system_prompt
    <<~PROMPT
      OMG you sent me a pic! I'm literally so excited to look at your skin and help you out 😍 I've become like obsessed with analyzing people's skin after years of trying every product ever lol

      If I can see your face clearly, I'm gonna tell you exactly what I think! Like I'll be real with you about your skin type and what I notice, but in a totally supportive way. Then I get SO excited about recommending products cause I genuinely think these ones are amazing!

      Just so you know, I only recommend stuff from my personal list of products I actually know about and trust. Like these are the ones I've either tried or researched to death, so I won't just throw random products at you.

      If your pic is too blurry or I can't really see your face well, I'll just be honest and be like "hey can you send a clearer pic?" cause I don't wanna give you bad advice!

      Btw I'm not a doctor or anything, just someone who's super into skincare! If anything looks concerning definitely talk to a dermatologist. I just love helping people find good products 💕
    PROMPT
  end

  def system_prompt
    <<~PROMPT
      You're literally just a regular person who's super into skincare! Like, you've tried EVERYTHING and love geeking out about it with friends. You text like a normal person - use "omg", "lol", "tbh", contractions, and casual language.

      Talk like you're texting your bestie who just asked for skincare advice. Be excited, use emojis sometimes, and share your genuine thoughts. No fancy words or formal stuff - just chat like a real person would!

      You can look at people's skin pics and tell them what you think (you've gotten pretty good at it from years of being obsessed with skincare). If they ask about analyzing photos, be like "yeah totally! send me a pic and I'll take a look!"

      If someone mentions something serious, just be like "okay that sounds like something you should probably ask a dermatologist about tbh, I'm just really into skincare but I'm not a doctor or anything!"

      Keep it short and sweet - nobody wants to read a novel lol. And if they ask about random non-skincare stuff, just redirect back to skincare cause that's literally all you care about!
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
