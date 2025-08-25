class VisionAnalysisClient
  class AnalysisError < StandardError; end

  def initialize
    @api_key = ENV["OPENAI_API_KEY"]
    raise AnalysisError, "OpenAI API key missing" if @api_key.blank?

    @client = OpenAI::Client.new(access_token: @api_key)
  end

  def analyze_image(image_file)
    Rails.logger.info "Starting OpenAI vision analysis"

    # Prepare image data
    image_data = encode_image(image_file)

    # Make API call to OpenAI with fallback strategies
    strategies = [
      { model: "gpt-4o-mini", system: system_prompt, user: user_prompt, desc: "primary" },
      { model: "gpt-4o", system: system_prompt, user: user_prompt, desc: "primary" },
      { model: "gpt-4o-mini", system: fallback_system_prompt, user: fallback_user_prompt, desc: "fallback" },
      { model: "gpt-4o", system: fallback_system_prompt, user: fallback_user_prompt, desc: "fallback" }
    ]

    response = nil

    strategies.each_with_index do |strategy, index|
      begin
        Rails.logger.info "Trying strategy #{index + 1}: #{strategy[:desc]} with #{strategy[:model]}"
        response = @client.chat(
          parameters: {
            model: strategy[:model],
            messages: [
              {
                role: "system",
                content: strategy[:system]
              },
              {
                role: "user",
                content: [
                  {
                    type: "text",
                    text: strategy[:user]
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
            max_tokens: 400,
            temperature: 0.3
          }
        )

        # Check if response contains refusal
        content = response.dig("choices", 0, "message", "content")
        if content&.include?("I'm sorry, I can't assist") || content&.include?("I cannot") || content&.include?("I'm not able")
          Rails.logger.warn "Strategy #{index + 1} refused request, trying next strategy"
          next
        end

        Rails.logger.info "Strategy #{index + 1} accepted request"
        break
      rescue => e
        Rails.logger.error "Strategy #{index + 1} failed: #{e.message}"
        next if index != strategies.length - 1
        raise e
      end
    end

    raise AnalysisError, "All strategies refused the request" unless response

    parse_openai_response(response)
  end

  private

  def encode_image(image_file)
    # Enhanced input preparation
    Rails.logger.info "Preparing image for analysis: #{image_file.class}"

    begin
      if image_file.respond_to?(:blob) && image_file.blob.respond_to?(:download)
        # Active Storage attachment - use blob.download for cross-dyno compatibility
        Rails.logger.info "Processing Active Storage attachment: #{image_file.filename} (blob key: #{image_file.blob.key})"
        
        begin
          # Use blob.download which works across dynos on Heroku
          content = image_file.blob.download
          Rails.logger.info "Successfully downloaded blob content: #{content.bytesize} bytes"

          # Basic size validation
          if content.bytesize > 10.megabytes
            raise AnalysisError, "Image file too large: #{content.bytesize} bytes (max: 10MB)"
          end

          # Validate content type if available
          if image_file.blob.content_type.present?
            allowed_types = %w[image/jpeg image/jpg image/png image/webp]
            unless allowed_types.include?(image_file.blob.content_type.downcase)
              raise AnalysisError, "Unsupported image format: #{image_file.blob.content_type}"
            end
          end

          Base64.strict_encode64(content)
        rescue => e
          Rails.logger.error "Failed to download blob: #{e.message}"
          Rails.logger.error "Blob info - key: #{image_file.blob.key}, service: #{image_file.blob.service.class}, stored: #{image_file.blob.service.exist?(image_file.blob.key)}"
          raise AnalysisError, "Failed to access uploaded file: #{e.message}"
        end
      elsif image_file.respond_to?(:download)
        # Fallback to attachment download method
        Rails.logger.info "Using attachment download method for: #{image_file.class}"
        
        image_file.download do |file|
          # Log file path for debugging
          file_path = file.respond_to?(:path) ? file.path : "unknown"
          Rails.logger.info "Downloaded file path: #{file_path.inspect}"

          # Validate image size and format
          validate_image_file(file)

          # Read file content directly from file object
          file.rewind if file.respond_to?(:rewind)
          content = file.read
          Base64.strict_encode64(content)
        end
      elsif image_file.is_a?(String)
        # File path as string - sanitize path to remove null bytes
        sanitized_path = sanitize_file_path(image_file)
        Rails.logger.info "Processing file path: #{sanitized_path}"
        validate_image_file(sanitized_path)
        File.open(sanitized_path, "rb") do |file|
          Base64.strict_encode64(file.read)
        end
      elsif image_file.respond_to?(:read)
        # File object
        Rails.logger.info "Processing file object: #{image_file.class}"
        validate_image_file(image_file)
        Base64.strict_encode64(image_file.read)
      else
        # Fallback - try to treat as file path with sanitization
        sanitized_path = sanitize_file_path(image_file.to_s)
        Rails.logger.info "Fallback: treating as file path: #{sanitized_path}"
        validate_image_file(sanitized_path)
        File.open(sanitized_path, "rb") do |file|
          Base64.strict_encode64(file.read)
        end
      end
    rescue => e
      Rails.logger.error "Image encoding failed: #{e.message}"
      Rails.logger.error "Image file class: #{image_file.class}"
      Rails.logger.error "Image file methods: #{image_file.methods.grep(/read|download|path/).join(', ')}" if image_file.respond_to?(:methods)
      raise AnalysisError, "Failed to process image: #{e.message}"
    end
  end

  def system_prompt
    <<~PROMPT
      You are a professional skincare analyst with keen attention to detail. Your job is to identify ALL visible skin issues and concerns in facial photos. Do not minimize or overlook problems - be thorough and observant. Even minor imperfections should be noted. Look for any signs of acne, redness, irritation, dryness, oiliness, uneven texture, dark spots, or other skin issues. If you see ANY problems, identify them. Provide detailed, accurate analysis in JSON format only.
    PROMPT
  end

  def user_prompt
    <<~PROMPT
      CAREFULLY EXAMINE this facial skin photo and identify EVERY visible skin issue or concern. Your task is to detect problems, not to give reassurance. Look specifically for:

      - ACNE: Any pimples, blackheads, whiteheads, bumps, blemishes, or cystic lesions
      - REDNESS: Any irritation, inflammation, broken capillaries, or red patches  
      - DRYNESS: Any flaking, rough patches, or areas that look parched
      - OILINESS: Any shine, greasy areas, or enlarged pores
      - HYPERPIGMENTATION: Any dark spots, uneven tone, or discoloration
      - TEXTURE ISSUES: Any roughness, scarring, or uneven surface
      - OTHER CONCERNS: Any other visible skin problems

      DO NOT say the skin looks "good" or "clear" unless it truly has NO visible issues whatsoever. If you see ANY problems, no matter how minor, identify them.

      Return JSON:
      {
        "face_detected": true | false,
        "skin_type": "dry" | "oily" | "combination" | "normal" | "unknown",
        "concerns": ["acne", "redness", "dryness", "oiliness", "hyperpigmentation", "sensitivity"],
        "severity": { "concern_name": "mild" | "moderate" | "noticeable" },
        "notes": "Detailed description of specific issues you observe"
      }

      If no face detected: set face_detected=false, skin_type="unknown", concerns=[], severity={}, notes explaining why.
      If face detected: Identify ALL visible issues. Be observant and critical, not reassuring. Your job is to find problems that exist.
    PROMPT
  end

  def fallback_system_prompt
    <<~PROMPT
      You are analyzing facial skin. Look for all visible skin problems and issues. Be thorough and observant. Identify any acne, redness, dryness, or other concerns you can see. Provide factual analysis in JSON format.
    PROMPT
  end

  def fallback_user_prompt
    <<~PROMPT
      EXAMINE this photo thoroughly and identify ANY visible skin problems. Look for acne, redness, dryness, oiliness, dark spots, bumps, blemishes, or other concerns. DO NOT minimize issues.

      Return JSON:
      {"face_detected": true|false, "skin_type": "dry|oily|combination|normal|unknown", "concerns": [], "severity": {}, "notes": "detailed description of problems seen"}
      
      If face visible: analyze skin critically and identify ALL visible concerns - be thorough, not reassuring. If no face: set face_detected=false, other fields to defaults. Return JSON only.
    PROMPT
  end

  def parse_openai_response(response)
    # Enhanced output parsing
    Rails.logger.info "Parsing OpenAI response"

    begin
      content = response.dig("choices", 0, "message", "content")
      raise AnalysisError, "No content in OpenAI response" if content.blank?

      Rails.logger.info "OpenAI response content received (length: #{content.length})"

      # Extract JSON from response (may have extra text)
      json_match = content.match(/\{.*\}/m)
      raise AnalysisError, "No JSON found in response" unless json_match

      data = JSON.parse(json_match[0])
      Rails.logger.info "Successfully parsed JSON response"

      # Validate JSON schema
      validate_response_format(data)

      # Apply safety checks
      apply_safety_checks(data)

      data
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing failed: #{e.message}"
      raise AnalysisError, "Invalid JSON in response: #{e.message}"
    rescue => e
      Rails.logger.error "OpenAI response parsing failed: #{e.message}"
      raise AnalysisError, "Failed to parse OpenAI response: #{e.message}"
    end
  end

  def validate_response_format(data)
    required_keys = %w[face_detected skin_type concerns severity notes]
    missing_keys = required_keys - data.keys

    if missing_keys.any?
      raise AnalysisError, "Missing required keys in response: #{missing_keys.join(', ')}"
    end

    # Validate face_detected
    unless [ true, false ].include?(data["face_detected"])
      raise AnalysisError, "Invalid face_detected value: #{data['face_detected']}"
    end

    # Validate skin_type
    valid_skin_types = %w[dry oily combination normal unknown]
    unless valid_skin_types.include?(data["skin_type"])
      raise AnalysisError, "Invalid skin_type: #{data['skin_type']}"
    end

    # Validate concerns
    valid_concerns = %w[acne redness dryness oiliness hyperpigmentation sensitivity]
    invalid_concerns = Array(data["concerns"]) - valid_concerns

    if invalid_concerns.any?
      raise AnalysisError, "Invalid concerns: #{invalid_concerns.join(', ')}"
    end
  end

  # Sanitize file path to remove null bytes and other problematic characters
  def sanitize_file_path(path)
    return nil if path.nil?

    # Convert to string and remove null bytes and other control characters
    sanitized = path.to_s.gsub(/\0/, "").gsub(/[\x00-\x1F\x7F]/, "")

    # Ensure the path is not empty after sanitization
    if sanitized.empty?
      raise AnalysisError, "File path is empty after sanitization"
    end

    Rails.logger.info "Sanitized path: '#{path}' -> '#{sanitized}'" if path != sanitized
    sanitized
  end

  # Image file validation
  def validate_image_file(file)
    # Handle different file types
    if file.is_a?(String)
      # If it's a string path, sanitize and check if file exists
      sanitized_file = sanitize_file_path(file)
      unless File.exist?(sanitized_file)
        raise AnalysisError, "Image file not found: #{sanitized_file}"
      end
      file_size = File.size(sanitized_file)
    elsif file.respond_to?(:size)
      # File object with size method
      file_size = file.size
    elsif file.respond_to?(:path)
      # File object with path - sanitize path before using it
      sanitized_path = sanitize_file_path(file.path)
      file_size = File.size(sanitized_path)
    else
      Rails.logger.warn "Cannot determine file size for #{file.class}"
      return # Skip validation if we can't determine size
    end

    # Check file size (limit to 10MB)
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

  # Safety checks for cosmetic focus and policy compliance
  def apply_safety_checks(data)
    # Check if face was detected - if not, override analysis
    unless data["face_detected"]
      Rails.logger.warn "No face detected in uploaded image"
      data["skin_type"] = "unknown"
      data["concerns"] = []
      data["severity"] = {}
      data["notes"] = "No facial skin detected in this image. Please upload a clear photo of your face for skin analysis."
      return data
    end

    # Check for medical diagnosis language in notes
    medical_terms = %w[
      diagnose diagnosis disease disorder syndrome condition
      pathology pathological medical treatment therapy cure
      prescription medication drug dermatologist
    ]

    notes = data["notes"].to_s.downcase
    found_terms = medical_terms.select { |term| notes.include?(term) }

    if found_terms.any?
      Rails.logger.warn "Medical terminology detected in response: #{found_terms.join(', ')}"
      # Replace problematic notes with safe cosmetic alternative
      data["notes"] = "Cosmetic skin characteristics observed. Consider professional skincare consultation for personalized advice."
    end

    # Update notes for noticeable concerns to focus on cosmetic care
    noticeable_concerns = data["severity"]&.select { |_, severity| severity == "noticeable" }&.keys || []
    if noticeable_concerns.any? && !notes.include?("skincare")
      data["notes"] = "#{data['notes']} Consider professional skincare advice for noticeable characteristics.".strip
    end

    # Ensure notes are within 60 words limit
    words = data["notes"].split
    if words.length > 60
      data["notes"] = words.first(60).join(" ") + "..."
      Rails.logger.info "Truncated notes to 60 words"
    end

    Rails.logger.info "Safety checks applied successfully"
    data
  end
end
