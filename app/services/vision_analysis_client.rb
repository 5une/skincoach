class VisionAnalysisClient
  include HTTParty

  class AnalysisError < StandardError; end

  def initialize
    @api_key = ENV['VISION_API_KEY']
    @api_endpoint = ENV['VISION_API_ENDPOINT'] 
    @provider = ENV['VISION_PROVIDER'] || 'azure' # 'azure' or 'google'
    
    raise AnalysisError, "Vision API configuration missing" if @api_key.blank? || @api_endpoint.blank?
    
    # Validate EU region for data residency (as per CURSOR.md requirement)
    validate_eu_region if @provider == 'azure'
  end

  def analyze_image(image_file)
    case @provider.downcase
    when 'azure'
      analyze_with_azure(image_file)
    when 'google'
      analyze_with_google(image_file)
    else
      raise AnalysisError, "Unsupported vision provider: #{@provider}"
    end
  end

  private

  def analyze_with_azure(image_file)
    # Prepare image data
    image_data = encode_image(image_file)

    # Construct the request
    payload = {
      messages: [
        {
          role: "system",
          content: system_prompt
        },
        {
          role: "user", 
          content: [
            {
              type: "text",
              text: user_prompt
            },
            {
              type: "image_url",
              image_url: {
                url: "data:image/jpeg;base64,#{image_data}"
              }
            }
          ]
        }
      ],
      max_tokens: 1000,
      temperature: 0.1
    }
    
    # Make the API call
    response = HTTParty.post(
      @api_endpoint,
      headers: {
        'Content-Type' => 'application/json',
        'api-key' => @api_key
      },
      body: payload.to_json,
      timeout: 60
    )
    
    parse_azure_response(response)
  end
  
  def analyze_with_google(image_file)
    # Prepare image data
    image_data = encode_image(image_file)
    
    # Construct the request for Google Vertex AI
    payload = {
      instances: [
        {
          prompt: user_prompt,
          image: {
            bytes_base64_encoded: image_data
          }
        }
      ],
      parameters: {
        temperature: 0.1,
        max_output_tokens: 1000
      }
    }
    
    # Make the API call
    response = HTTParty.post(
      @api_endpoint,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@api_key}"
      },
      body: payload.to_json,
      timeout: 60
    )

    parse_google_response(response)
  end

  def encode_image(image_file)
    # Enhanced input preparation as per CURSOR.md step 2
    Rails.logger.info "Preparing image for analysis: #{image_file.class}"
    
    begin
      if image_file.respond_to?(:download)
        # Active Storage attachment - download and encode
        Rails.logger.info "Processing Active Storage attachment: #{image_file.filename}"
        image_file.download do |file|
          # Validate image size and format
          validate_image_file(file)
          Base64.strict_encode64(file.read)
        end
      elsif image_file.respond_to?(:read)
        # File object
        validate_image_file(image_file)
        Base64.strict_encode64(image_file.read)
      else
        # File path
        File.open(image_file, 'rb') do |file|
          validate_image_file(file)
          Base64.strict_encode64(file.read)
        end
      end
    rescue => e
      Rails.logger.error "Image encoding failed: #{e.message}"
      raise AnalysisError, "Failed to process image: #{e.message}"
    end
  end

  def system_prompt
    # Enhanced system prompt as per CURSOR.md step 3
    <<~PROMPT
      You are a cautious dermatology assistant AI that analyzes facial skin images. Your role is strictly observational and educational.

      CRITICAL REQUIREMENTS:
      - You CANNOT diagnose medical conditions or provide medical advice
      - You CANNOT recommend specific treatments or medications  
      - You MUST remain factual and neutral in all observations
      - You MUST suggest consulting a dermatologist for severe or persistent symptoms
      - You MUST avoid any language that could be construed as medical diagnosis

      ANALYSIS SCOPE:
      - Observe visible skin characteristics (type, texture, visible concerns)
      - Note apparent skin conditions (acne, redness, dryness, etc.) as observations only
      - Assess severity levels as mild, moderate, or severe based on visual appearance
      - Provide brief, neutral notes without diagnostic terminology

      You will respond with ONLY a valid JSON object in the exact format specified. No additional text, explanations, or commentary.
    PROMPT
  end

  def user_prompt
    # Enhanced user prompt as per CURSOR.md step 3 specifications
    <<~PROMPT
      Analyze this facial skin image and provide a JSON response with this EXACT structure:

      {
        "skin_type": "dry" | "oily" | "combination" | "normal" | "unknown",
        "concerns": ["acne", "redness", "dryness", "oiliness", "hyperpigmentation", "sensitivity"],
        "severity": {
          "concern_name": "mild" | "moderate" | "severe"
        },
        "notes": "Brief neutral observations (≤60 words, no diagnosis)"
      }

      STRICT GUIDELINES:
      - skin_type: Choose ONE from the 5 options. Use "unknown" if uncertain.
      - concerns: Array of visible concerns only. Valid options: acne, redness, dryness, oiliness, hyperpigmentation, sensitivity
      - severity: Object mapping ONLY concerns that are present to severity levels
      - notes: Maximum 60 words, factual observations without medical diagnosis

      SAFETY REQUIREMENTS:
      - NO medical diagnosis language (avoid: "condition", "disease", "disorder", "syndrome")
      - NO treatment recommendations
      - For severe concerns: mention "consider consulting a dermatologist"
      - Use observational language: "appears", "visible", "observed"

      Respond with ONLY the JSON object. No additional text, explanations, or formatting.
    PROMPT
  end

  def parse_azure_response(response)
    unless response.success?
      raise AnalysisError, "Azure API error: #{response.code} - #{response.body}"
    end

    content = response.dig('choices', 0, 'message', 'content')
    raise AnalysisError, "No content in Azure response" if content.blank?

    parse_json_response(content)
  end

  def parse_google_response(response)
    unless response.success?
      raise AnalysisError, "Google API error: #{response.code} - #{response.body}"
    end

    content = response.dig('predictions', 0, 'content')
    raise AnalysisError, "No content in Google response" if content.blank?

    parse_json_response(content)
  end

  def parse_json_response(content)
    # Enhanced output parsing as per CURSOR.md step 5
    Rails.logger.info "Parsing API response content (length: #{content.length})"
    
    # Extract JSON from response (may have extra text)
    json_match = content.match(/\{.*\}/m)
    raise AnalysisError, "No JSON found in response" unless json_match
    
    begin
      data = JSON.parse(json_match[0])
      Rails.logger.info "Successfully parsed JSON response"
      
      # Validate JSON schema as per CURSOR.md requirements
      validate_response_format(data)
      
      # Apply safety checks as per CURSOR.md step 6
      apply_safety_checks(data)
      
      data
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing failed: #{e.message}"
      raise AnalysisError, "Invalid JSON in response: #{e.message}"
    end
  end

  def validate_response_format(data)
    required_keys = %w[skin_type concerns severity notes]
    missing_keys = required_keys - data.keys

    if missing_keys.any?
      raise AnalysisError, "Missing required keys in response: #{missing_keys.join(', ')}"
    end

    # Validate skin_type
    valid_skin_types = %w[dry oily combination normal unknown]
    unless valid_skin_types.include?(data['skin_type'])
      raise AnalysisError, "Invalid skin_type: #{data['skin_type']}"
    end

    # Validate concerns
    valid_concerns = %w[acne redness dryness oiliness hyperpigmentation sensitivity]
    invalid_concerns = Array(data['concerns']) - valid_concerns

    if invalid_concerns.any?
      raise AnalysisError, "Invalid concerns: #{invalid_concerns.join(', ')}"
    end
  end

  # EU region validation for data residency (CURSOR.md step 4)
  def validate_eu_region
    eu_regions = %w[
      westeurope northeurope uksouth ukwest francecentral germanywestcentral
      norwayeast swedencentral switzerlandnorth
    ]

    unless eu_regions.any? { |region| @api_endpoint.include?(region) }
      Rails.logger.warn "Azure endpoint may not be in EU region for data residency compliance"
    end
  end

  # Image file validation (CURSOR.md step 2)
  def validate_image_file(file)
    # Check file size (limit to 10MB)
    file_size = file.respond_to?(:size) ? file.size : File.size(file.path)
    if file_size > 10.megabytes
      raise AnalysisError, "Image file too large: #{file_size} bytes (max: 10MB)"
    end

    # Validate image format if we can detect it
    if file.respond_to?(:content_type)
      allowed_types = %w[image/jpeg image/jpg image/png image/webp]
      unless allowed_types.include?(file.content_type.downcase)
        raise AnalysisError, "Unsupported image format: #{file.content_type}"
      end
    end

    Rails.logger.info "Image validation passed: #{file_size} bytes"
  end

  # Safety checks for medical diagnosis prevention (CURSOR.md step 6)
  def apply_safety_checks(data)
    # Check for medical diagnosis language in notes
    medical_terms = %w[
      diagnose diagnosis disease disorder syndrome condition 
      pathology pathological medical treatment therapy cure
      prescription medication drug
    ]
    
    notes = data['notes'].to_s.downcase
    found_terms = medical_terms.select { |term| notes.include?(term) }
    
    if found_terms.any?
      Rails.logger.warn "Medical terminology detected in response: #{found_terms.join(', ')}"
      # Replace problematic notes with safe alternative
      data['notes'] = "Skin observations completed. For persistent concerns, consider consulting a dermatologist."
    end

    # Add dermatologist recommendation for severe concerns
    severe_concerns = data['severity']&.select { |_, severity| severity == 'severe' }&.keys || []
    if severe_concerns.any? && !notes.include?('dermatologist')
      data['notes'] = "#{data['notes']} Consider consulting a dermatologist for severe concerns.".strip
    end

    # Ensure notes are within 60 words limit
    words = data['notes'].split
    if words.length > 60
      data['notes'] = words.first(60).join(' ') + '...'
      Rails.logger.info "Truncated notes to 60 words"
    end

    Rails.logger.info "Safety checks applied successfully"
  end
end
