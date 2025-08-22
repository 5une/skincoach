class AiRecommendationEngine
  class RecommendationError < StandardError; end

  def initialize(analysis_data)
    @face_detected = analysis_data["face_detected"]
    @skin_type = analysis_data["skin_type"]
    @concerns = Array(analysis_data["concerns"])
    @severity = analysis_data["severity"] || {}
    @notes = analysis_data["notes"]
    @openai_client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
  end

  def generate_recommendations
    # Don't generate product recommendations if no face was detected
    unless @face_detected
      return {
        picks: {},
        rationale: "No facial skin detected in the uploaded image. Please upload a clear photo of your face to receive personalized skincare product recommendations."
      }
    end

    begin
      Rails.logger.info "Starting AI-powered product recommendation generation"

      # Get all available products from database
      products_data = prepare_products_data

      # Use AI to select best products for each category
      ai_selections = get_ai_product_selections(products_data)

      # Format the selections into the expected structure
      format_recommendations(ai_selections)

    rescue => e
      Rails.logger.error "AI recommendation generation failed: #{e.message}"
    end
  end

  private

  def prepare_products_data
    # Group products by category with essential information
    products_by_category = {}

    Product::CATEGORIES.each do |category|
      products = Product.by_category(category).limit(10).map do |product|
        {
          id: product.id,
          name: product.name,
          brand: product.brand,
          price: product.price.to_f,
          key_ingredients: product.key_ingredients || "",
          skin_concerns: product.skin_concerns || "",
          comedogenic_rating: product.comedogenic_rating,
          product_url: product.product_url,
          image_url: product.image_url
        }
      end

      products_by_category[category] = products if products.any?
    end

    products_by_category
  end

  def get_ai_product_selections(products_data)
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt(products_data)

    Rails.logger.info "Sending product recommendation request to OpenAI"

    response = @openai_client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
                    max_tokens: 800,
            temperature: 0
      }
    )

    content = response.dig("choices", 0, "message", "content")
    raise RecommendationError, "No content in OpenAI response" if content.blank?

    # Extract JSON from response
    json_match = content.match(/\{.*\}/m)
    raise RecommendationError, "No JSON found in response" unless json_match

    JSON.parse(json_match[0])
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parsing failed: #{e.message}"
    raise RecommendationError, "Invalid JSON in recommendation response"
  end

  def build_system_prompt
    <<~PROMPT
      Expert skincare consultant. Recommend products from database based on skin analysis. Match ingredients to concerns, consider comedogenic ratings for acne, avoid irritants for sensitive skin. Only recommend necessary categories. Respond in JSON format only.
    PROMPT
  end

  def build_user_prompt(products_data)
    concerns_text = @concerns.any? ? @concerns.join(", ") : "none specified"
    severity_text = @severity.any? ? @severity.map { |k, v| "#{k}: #{v}" }.join(", ") : "none specified"

    <<~PROMPT
      Analyze this skin profile and recommend the BEST products from our database:

      SKIN PROFILE:
      - Skin Type: #{@skin_type}
      - Main Concerns: #{concerns_text}
      - Concern Severity: #{severity_text}
      - Analysis Notes: #{@notes}

      AVAILABLE PRODUCTS:
      #{format_products_for_ai(products_data)}

      TASK: Recommend ONLY the necessary products for this specific skin profile. You don't need to select from every category - only recommend categories that are needed based on the skin analysis.

      SELECTION CRITERIA:
      - Match active ingredients to skin concerns
      - Consider comedogenic ratings (≤2 for acne-prone skin)
      - Avoid fragrances for sensitive skin
      - Prioritize proven ingredients for specific concerns
      - Consider price range variety
      - Ensure products complement each other
      - Only recommend categories that are actually needed for this skin profile

      CATEGORY GUIDELINES:
      - cleanser: Always needed for basic skincare
      - moisturizer: Always needed for hydration
      - sunscreen: Always needed for protection
      - serum: Only if specific concerns need targeted treatment
      - spot_treatment: Only if acne is present

      Return JSON in this EXACT format:
      {
        "selections": {
          "cleanser": [product_id1, product_id2],
          "moisturizer": [product_id1, product_id2],
          "sunscreen": [product_id1, product_id2],
          "serum": [product_id1, product_id2],
          "spot_treatment": [product_id1]
        },
        "rationale": "Detailed explanation of why these specific products and categories were chosen based on the skin analysis, mentioning key ingredients and how they address the identified concerns."
      }

      IMPORTANT: Only include categories in the selections object that are actually needed. For example, if no acne is present, don't include spot_treatment. If skin is normal with no specific concerns, you might only need cleanser, moisturizer, and sunscreen.

      Select only products that exist in the provided database. Return ONLY the JSON.
    PROMPT
  end

  def format_products_for_ai(products_data)
    formatted = []

    products_data.each do |category, products|
      formatted << "\n#{category.upcase}:"
      products.each do |product|
        formatted << "ID: #{product[:id]} | #{product[:brand]} #{product[:name]} | $#{product[:price]} | Ingredients: #{product[:key_ingredients]} | For: #{product[:skin_concerns]} | Comedogenic: #{product[:comedogenic_rating] || 'N/A'}"
      end
    end

    formatted.join("\n")
  end

  def format_recommendations(ai_selections)
    selections = ai_selections["selections"] || {}
    rationale = ai_selections["rationale"] || "Products selected based on skin analysis."

    picks = {}

    Product::CATEGORIES.each do |category|
      product_ids = Array(selections[category]).compact
      next if product_ids.empty?

      products = Product.where(id: product_ids).map do |product|
        {
          "name" => product.name,
          "brand" => product.brand,
          "price" => product.price.to_f,
          "url" => product.product_url,
          "image" => product.image_url,
          "tags" => product.skin_concerns_array,
          "ingredients" => product.key_ingredients_array
        }
      end

      picks[category] = products if products.any?
    end

    {
      picks: picks,
      rationale: rationale
    }
  end
end
