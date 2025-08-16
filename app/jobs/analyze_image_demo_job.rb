class AnalyzeImageDemoJob < ApplicationJob
  queue_as :default

  def perform(consultation)
    # Simulate analysis process
    consultation.update!(status: 'analyzing')

    # Wait a bit to simulate processing time
    sleep(5)

    # Generate demo analysis data
    demo_analysis = {
      skin_type: ['dry', 'oily', 'combination', 'normal'].sample,
      concerns: ['acne', 'redness', 'dryness', 'oiliness', 'hyperpigmentation'].sample(rand(1..3)),
      severity: {
        'acne' => ['mild', 'moderate', 'noticeable'].sample,
        'redness' => ['mild', 'moderate', 'noticeable'].sample
      },
      notes: "Cosmetic skin characteristics observed for skincare product selection. Consider a gentle routine with suitable products for your skin type."
    }

    # Generate demo recommendations using actual products from database
    demo_recommendations = generate_demo_recommendations(demo_analysis[:concerns])

    # Update consultation with results
    consultation.update!(
      status: 'completed',
      analysis_data: demo_analysis,
      recommendations_data: demo_recommendations
    )

  rescue => e
    consultation.update!(
      status: 'failed',
      error_message: "Analysis failed: #{e.message}"
    )
  end

  private

  def generate_demo_recommendations(concerns)
    picks = {}

    # Get products for each category
    Product::CATEGORIES.each do |category|
      products = Product.by_category(category).limit(2)

      picks[category] = products.map do |product|
        {
          'name' => product.name,
          'brand' => product.brand,
          'price' => product.price.to_f,
          'url' => product.product_url,
          'image' => product.image_url,
          'tags' => product.skin_concerns_array
        }
      end
    end
  
    {
      picks: picks,
      rationale: "Based on your skin concerns (#{concerns.join(', ')}), we've selected products that are gentle, effective, and suitable for your skin type."
    }
  end
end