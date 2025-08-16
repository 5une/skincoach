class RecommendationEngine
  class RecommendationError < StandardError; end

  def initialize(analysis_data)
    @face_detected = analysis_data["face_detected"]
    @skin_type = analysis_data["skin_type"]
    @concerns = Array(analysis_data["concerns"])
    @severity = analysis_data["severity"] || {}
  end

  def generate_recommendations
    # Don't generate product recommendations if no face was detected
    unless @face_detected
      return {
        picks: {},
        rationale: "No facial skin detected in the uploaded image. Please upload a clear photo of your face to receive personalized skincare product recommendations."
      }
    end

    {
      picks: generate_category_picks,
      rationale: generate_rationale
    }
  end

  private

  def generate_category_picks
    picks = {}

    Product::CATEGORIES.each do |category|
      picks[category] = recommend_for_category(category)
    end

    picks
  end

  def recommend_for_category(category)
    # Start with products in this category
    products = Product.by_category(category)

    # Apply concern-based filtering
    if @concerns.present?
      # Find products that address at least one of the user's concerns
      concern_conditions = @concerns.map { "skin_concerns LIKE ?" }
      concern_values = @concerns.map { |concern| "%#{concern}%" }
      products = products.where(concern_conditions.join(" OR "), *concern_values)
    end

    # Apply safety filters based on concerns
    products = apply_safety_filters(products, category)

    # Apply skin type preferences
    products = apply_skin_type_preferences(products, category)

    # Limit to top picks and convert to hash format
    products.limit(3).map do |product|
      {
        "name" => product.name,
        "brand" => product.brand,
        "price" => product.price.to_f,
        "url" => product.product_url,
        "image" => product.image_url,
        "tags" => product.skin_concerns_array
      }
    end
  end

  def apply_safety_filters(products, category)
    filtered_products = products

    # Acne-prone skin: low comedogenic rating
    if @concerns.include?("acne")
      filtered_products = filtered_products.low_comedogenic
    end

    # Sensitive skin: fragrance-free
    if @concerns.include?("sensitivity")
      filtered_products = filtered_products.fragrance_free
    end

    # Redness: prioritize niacinamide and soothing ingredients
    if @concerns.include?("redness")
      niacinamide_products = filtered_products.where("key_ingredients LIKE ?", "%niacinamide%")
      soothing_products = filtered_products.where(
        "key_ingredients LIKE ? OR key_ingredients LIKE ? OR key_ingredients LIKE ?",
        "%aloe%", "%chamomile%", "%centella%"
      )

      # Prefer products with soothing ingredients, fallback to all products
      preferred = niacinamide_products.or(soothing_products)
      filtered_products = preferred.exists? ? preferred : filtered_products
    end

    # Hyperpigmentation: prioritize vitamin C, retinol, alpha arbutin
    if @concerns.include?("hyperpigmentation")
      brightening_products = filtered_products.where(
        "key_ingredients LIKE ? OR key_ingredients LIKE ? OR key_ingredients LIKE ? OR key_ingredients LIKE ?",
        "%vitamin c%", "%retinol%", "%alpha arbutin%", "%kojic acid%"
      )

      filtered_products = brightening_products.exists? ? brightening_products : filtered_products
    end

    # Oily skin: oil-free, mattifying ingredients
    if @concerns.include?("oiliness")
      oil_control_products = filtered_products.where(
        "key_ingredients LIKE ? OR key_ingredients LIKE ? OR key_ingredients LIKE ?",
        "%salicylic acid%", "%niacinamide%", "%zinc%"
      )

      filtered_products = oil_control_products.exists? ? oil_control_products : filtered_products
    end

    # Dryness: hydrating ingredients
    if @concerns.include?("dryness")
      hydrating_products = filtered_products.where(
        "key_ingredients LIKE ? OR key_ingredients LIKE ? OR key_ingredients LIKE ? OR key_ingredients LIKE ?",
        "%hyaluronic acid%", "%ceramides%", "%glycerin%", "%squalane%"
      )

      filtered_products = hydrating_products.exists? ? hydrating_products : filtered_products
    end

    # Return filtered products, or original if no results
    filtered_products.exists? ? filtered_products : products
  end

  def apply_skin_type_preferences(products, category)
    case @skin_type
    when "oily"
      # Prefer gel textures, oil-free formulas
      if category == "moisturizer"
        gel_moisturizers = products.where("name LIKE ? OR key_ingredients LIKE ?", "%gel%", "%dimethicone%")
        return gel_moisturizers.exists? ? gel_moisturizers : products
      end
    when "dry"
      # Prefer cream textures, rich formulations
      if category == "moisturizer"
        cream_moisturizers = products.where(
          "name LIKE ? OR key_ingredients LIKE ? OR key_ingredients LIKE ?",
          "%cream%", "%ceramides%", "%shea butter%"
        )
        return cream_moisturizers.exists? ? cream_moisturizers : products
      end
    when "sensitive"
      # Already handled in safety filters
    end

    products
  end

  def generate_rationale
    rationale_parts = []

    # Skin type consideration
    unless @skin_type == "unknown"
      rationale_parts << "Selected products suitable for #{@skin_type} skin"
    end

    # Concern-specific rationale
    if @concerns.include?("acne")
      rationale_parts << "non-comedogenic formulas to prevent clogged pores"
    end

    if @concerns.include?("sensitivity")
      rationale_parts << "fragrance-free and gentle ingredients to minimize irritation"
    end

    if @concerns.include?("redness")
      rationale_parts << "soothing ingredients like niacinamide to calm inflammation"
    end

    if @concerns.include?("hyperpigmentation")
      rationale_parts << "brightening actives to help even skin tone"
    end

    if @concerns.include?("oiliness")
      rationale_parts << "oil-controlling ingredients to manage shine"
    end

    if @concerns.include?("dryness")
      rationale_parts << "hydrating ingredients to restore moisture"
    end

    # Severity considerations
    severe_concerns = @severity.select { |_, severity| severity == "severe" }.keys
    if severe_concerns.any?
      rationale_parts << "gentle formulations recommended due to severity of concerns"
    end

    # Build final rationale
    if rationale_parts.empty?
      "These products are selected based on general skin health principles and quality ingredients."
    else
      base = "Based on your skin analysis, we've chosen products with "
      concerns_text = rationale_parts.join(", ")
      "#{base}#{concerns_text}. Start slowly with new products and always patch test first."
    end
  end
end
