class VisionAnalysisClient
  include HTTParty

  class AnalysisError < StandardError; end

  def initialize
    @api_key = ENV['VISION_API_KEY']
    @api_endpoint = ENV['VISION_API_ENDPOINT'] 
    @provider = ENV['VISION_PROVIDER'] || 'azure' # 'azure' or 'google'

    raise AnalysisError, "Vision API configuration missing" if @api_key.blank? || @api_endpoint.blank?
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
    # Read and encode the image file
    if image_file.respond_to?(:download)
      # Active Storage attachment
      image_file.download do |file|
        Base64.strict_encode64(file.read)
      end
    elsif image_file.respond_to?(:read)
      # File object
      Base64.strict_encode64(image_file.read)
    else
      # File path
      Base64.strict_encode64(File.read(image_file))
    end
  end

  def system_prompt
    <<~PROMPT
      You are a cautious dermatology assistant AI. Your role is to analyze facial skin images and provide structured observations about skin type and visible concerns. 

      IMPORTANT LIMITATIONS:
      - You cannot diagnose medical conditions
      - You cannot provide medical advice
      - You should recommend consulting a dermatologist for persistent or severe issues
      - Keep observations factual and neutral

      You will analyze the image and respond with ONLY a valid JSON object in the exact format specified.
    PROMPT
  end

  def user_prompt
    <<~PROMPT
      Please analyze this facial skin image and provide a JSON response with the following structure:

      {
        "skin_type": "dry" | "oily" | "combination" | "normal" | "unknown",
        "concerns": ["acne", "redness", "dryness", "oiliness", "hyperpigmentation", "sensitivity"],
        "severity": {
          "acne": "mild" | "moderate" | "severe",
          "redness": "mild" | "moderate" | "severe",
          "dryness": "mild" | "moderate" | "severe",
          "oiliness": "mild" | "moderate" | "severe",
          "hyperpigmentation": "mild" | "moderate" | "severe",
          "sensitivity": "mild" | "moderate" | "severe"
        },
        "notes": "Brief neutral observations (max 60 words, no diagnosis)"
      }

      Guidelines:
      - Only include concerns that are clearly visible
      - Use "unknown" for skin type if uncertain
      - Only include severity ratings for concerns that are present
      - Keep notes factual and avoid medical terminology
      - If severe concerns are visible, mention consulting a dermatologist in notes

      Respond with ONLY the JSON object, no additional text.
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
    # Extract JSON from response (may have extra text)
    json_match = content.match(/\{.*\}/m)
    raise AnalysisError, "No JSON found in response" unless json_match

    begin
      data = JSON.parse(json_match[0])
      validate_response_format(data)
      data
    rescue JSON::ParserError => e
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
end
