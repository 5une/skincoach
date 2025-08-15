# Clear existing products
Product.delete_all

puts "Seeding skincare products..."

# Define product data
products_data = [
  # Cleansers
  {
    name: "Gentle Foaming Cleanser", brand: "CeraVe", category: "cleanser", price: 12.99,
    key_ingredients: "ceramides, hyaluronic acid, niacinamide", skin_concerns: "dryness, sensitivity", comedogenic_rating: 1
  },
  {
    name: "Salicylic Acid Cleanser", brand: "The INKEY List", category: "cleanser", price: 9.99,
    key_ingredients: "salicylic acid, zinc compound", skin_concerns: "acne, oiliness", comedogenic_rating: 0
  },
  {
    name: "Hydrating Cleanser", brand: "Vanicream", category: "cleanser", price: 8.99,
    key_ingredients: "glycerin, sodium lauroyl lactylate", skin_concerns: "dryness, sensitivity", comedogenic_rating: 0
  },
  {
    name: "Purifying Gel Cleanser", brand: "Neutrogena", category: "cleanser", price: 7.49,
    key_ingredients: "glycerin, sodium cocoyl isethionate", skin_concerns: "oiliness, acne", comedogenic_rating: 1
  },
  {
    name: "Micellar Cleansing Water", brand: "Garnier", category: "cleanser", price: 6.99,
    key_ingredients: "micelles, glycerin", skin_concerns: "sensitivity, dryness", comedogenic_rating: 0
  },
  {
    name: "Oil Cleanser", brand: "DHC", category: "cleanser", price: 28.00,
    key_ingredients: "olive oil, rosemary extract", skin_concerns: "dryness, hyperpigmentation", comedogenic_rating: 2
  },
  {
    name: "Exfoliating Cleanser", brand: "Paula's Choice", category: "cleanser", price: 18.00,
    key_ingredients: "glycolic acid, chamomile extract", skin_concerns: "hyperpigmentation, acne", comedogenic_rating: 0
  },
  {
    name: "Cream Cleanser", brand: "Cetaphil", category: "cleanser", price: 9.99,
    key_ingredients: "glycerin, cetyl alcohol", skin_concerns: "sensitivity, dryness", comedogenic_rating: 0
  },

  # Serums
  {
    name: "Niacinamide 10% + Zinc 1%", brand: "The Ordinary", category: "serum", price: 7.90,
    key_ingredients: "niacinamide, zinc PCA", skin_concerns: "acne, oiliness, redness", comedogenic_rating: 0
  },
  {
    name: "Hyaluronic Acid 2% + B5", brand: "The Ordinary", category: "serum", price: 8.90,
    key_ingredients: "hyaluronic acid, vitamin B5", skin_concerns: "dryness, sensitivity", comedogenic_rating: 0
  },
  {
    name: "Vitamin C Serum", brand: "Skinceuticals", category: "serum", price: 169.00,
    key_ingredients: "L-ascorbic acid, vitamin E, ferulic acid", skin_concerns: "hyperpigmentation, dryness", comedogenic_rating: 1
  },
  {
    name: "Retinol 0.5% in Squalane", brand: "The Ordinary", category: "serum", price: 9.90,
    key_ingredients: "retinol, squalane", skin_concerns: "acne, hyperpigmentation", comedogenic_rating: 1
  },
  {
    name: "Alpha Arbutin 2% + HA", brand: "The Ordinary", category: "serum", price: 8.90,
    key_ingredients: "alpha arbutin, hyaluronic acid", skin_concerns: "hyperpigmentation", comedogenic_rating: 0
  },
  {
    name: "BHA Liquid Exfoliant", brand: "Paula's Choice", category: "serum", price: 32.00,
    key_ingredients: "salicylic acid, green tea extract", skin_concerns: "acne, oiliness", comedogenic_rating: 0
  },
  {
    name: "Peptide Serum", brand: "No7", category: "serum", price: 39.99,
    key_ingredients: "peptides, antioxidants", skin_concerns: "sensitivity, dryness", comedogenic_rating: 1
  },
  {
    name: "Azelaic Acid Suspension 10%", brand: "The Ordinary", category: "serum", price: 8.10,
    key_ingredients: "azelaic acid", skin_concerns: "acne, redness, hyperpigmentation", comedogenic_rating: 0
  },
  {
    name: "Caffeine Solution 5% + EGCG", brand: "The Ordinary", category: "serum", price: 7.90,
    key_ingredients: "caffeine, EGCG", skin_concerns: "puffiness, sensitivity", comedogenic_rating: 0
  },
  {
    name: "Mandelic Acid 10% + HA", brand: "The Ordinary", category: "serum", price: 7.90,
    key_ingredients: "mandelic acid, hyaluronic acid", skin_concerns: "acne, sensitivity, hyperpigmentation", comedogenic_rating: 0
  },

  # Moisturizers
  {
    name: "Daily Moisturizing Lotion", brand: "CeraVe", category: "moisturizer", price: 16.99,
    key_ingredients: "ceramides, hyaluronic acid, MVE technology", skin_concerns: "dryness, sensitivity", comedogenic_rating: 1
  },
  {
    name: "Ultra Facial Cream", brand: "Kiehl's", category: "moisturizer", price: 31.00,
    key_ingredients: "glacial glycoprotein, urea, squalane", skin_concerns: "dryness", comedogenic_rating: 2
  },
  {
    name: "Dramatically Different Moisturizing Gel", brand: "Clinique", category: "moisturizer", price: 29.50,
    key_ingredients: "hyaluronic acid, glycerin", skin_concerns: "oiliness, sensitivity", comedogenic_rating: 0
  },
  {
    name: "Natural Moisturizing Factors + HA", brand: "The Ordinary", category: "moisturizer", price: 7.90,
    key_ingredients: "amino acids, fatty acids, hyaluronic acid", skin_concerns: "dryness, sensitivity", comedogenic_rating: 1
  },
  {
    name: "Oil-Free Moisture Gel", brand: "Neutrogena", category: "moisturizer", price: 7.99,
    key_ingredients: "glycerin, dimethicone", skin_concerns: "oiliness, acne", comedogenic_rating: 0
  },
  {
    name: "Toleriane Double Repair Face Moisturizer", brand: "La Roche-Posay", category: "moisturizer", price: 19.99,
    key_ingredients: "niacinamide, ceramides, thermal spring water", skin_concerns: "sensitivity, redness, dryness", comedogenic_rating: 0
  },
  {
    name: "Intense Hydrating Cream", brand: "Vanicream", category: "moisturizer", price: 12.99,
    key_ingredients: "petrolatum, glycerin, sorbitol", skin_concerns: "dryness, sensitivity", comedogenic_rating: 0
  },
  {
    name: "Water Gel Moisturizer", brand: "Olay", category: "moisturizer", price: 28.99,
    key_ingredients: "hyaluronic acid, niacinamide", skin_concerns: "dryness, oiliness", comedogenic_rating: 1
  },

  # Sunscreens
  {
    name: "Invisible Fluid Sunscreen SPF 60", brand: "La Roche-Posay", category: "sunscreen", price: 35.99,
    key_ingredients: "avobenzone, octinoxate, zinc oxide", skin_concerns: "sensitivity, hyperpigmentation", comedogenic_rating: 0
  },
  {
    name: "Mineral Sunscreen SPF 30", brand: "EltaMD", category: "sunscreen", price: 37.00,
    key_ingredients: "zinc oxide, niacinamide", skin_concerns: "acne, redness, sensitivity", comedogenic_rating: 0
  },
  {
    name: "Chemical Sunscreen SPF 50", brand: "Supergoop!", category: "sunscreen", price: 36.00,
    key_ingredients: "avobenzone, octisalate, homosalate", skin_concerns: "oiliness", comedogenic_rating: 1
  },
  {
    name: "Tinted Mineral Sunscreen SPF 40", brand: "CeraVe", category: "sunscreen", price: 17.99,
    key_ingredients: "zinc oxide, titanium dioxide, ceramides", skin_concerns: "dryness, sensitivity", comedogenic_rating: 1
  },
  {
    name: "Sport Sunscreen SPF 50", brand: "Neutrogena", category: "sunscreen", price: 8.97,
    key_ingredients: "avobenzone, homosalate, octisalate", skin_concerns: "oiliness", comedogenic_rating: 2
  },
  {
    name: "Daily Facial Sunscreen SPF 35", brand: "Aveeno", category: "sunscreen", price: 9.97,
    key_ingredients: "zinc oxide, oat extract", skin_concerns: "sensitivity, dryness", comedogenic_rating: 1
  },
  {
    name: "Clear Zinc Sunscreen SPF 45", brand: "Blue Lizard", category: "sunscreen", price: 14.99,
    key_ingredients: "zinc oxide, titanium dioxide", skin_concerns: "acne, sensitivity", comedogenic_rating: 0
  },

  # Spot Treatments
  {
    name: "Benzoyl Peroxide 2.5%", brand: "Paula's Choice", category: "spot_treatment", price: 19.00,
    key_ingredients: "benzoyl peroxide", skin_concerns: "acne", comedogenic_rating: 0
  },
  {
    name: "Salicylic Acid Spot Treatment", brand: "Clean & Clear", category: "spot_treatment", price: 4.97,
    key_ingredients: "salicylic acid", skin_concerns: "acne", comedogenic_rating: 0
  },
  {
    name: "Tea Tree Oil Spot Treatment", brand: "The Body Shop", category: "spot_treatment", price: 12.00,
    key_ingredients: "tea tree oil, salicylic acid", skin_concerns: "acne, redness", comedogenic_rating: 1
  },
  {
    name: "Hydrocolloid Acne Patches", brand: "COSRX", category: "spot_treatment", price: 6.00,
    key_ingredients: "hydrocolloid", skin_concerns: "acne", comedogenic_rating: 0
  },
  {
    name: "Sulfur Spot Treatment", brand: "Mario Badescu", category: "spot_treatment", price: 17.00,
    key_ingredients: "sulfur, zinc oxide, calamine", skin_concerns: "acne, oiliness", comedogenic_rating: 1
  },
  {
    name: "Retinol Spot Treatment", brand: "Differin", category: "spot_treatment", price: 12.88,
    key_ingredients: "adapalene", skin_concerns: "acne, hyperpigmentation", comedogenic_rating: 0
  },
  {
    name: "Niacinamide Spot Treatment", brand: "Good Molecules", category: "spot_treatment", price: 6.00,
    key_ingredients: "niacinamide, zinc, salicylic acid", skin_concerns: "acne, redness, oiliness", comedogenic_rating: 0
  },

  # Additional products to reach 50
  {
    name: "Gentle Micellar Foam", brand: "Bioderma", category: "cleanser", price: 15.90,
    key_ingredients: "micellar technology, cucumber extract", skin_concerns: "sensitivity, redness", comedogenic_rating: 0
  },
  {
    name: "Glycolic Acid Toner", brand: "Pixi", category: "serum", price: 18.00,
    key_ingredients: "glycolic acid, aloe vera, ginseng", skin_concerns: "hyperpigmentation, dryness", comedogenic_rating: 0
  },
  {
    name: "Recovery Night Cream", brand: "Olay", category: "moisturizer", price: 24.99,
    key_ingredients: "peptides, niacinamide, amino-peptides", skin_concerns: "dryness, sensitivity", comedogenic_rating: 1
  },
  {
    name: "Mineral Powder SPF 20", brand: "BareMinerals", category: "sunscreen", price: 32.00,
    key_ingredients: "zinc oxide, titanium dioxide, minerals", skin_concerns: "sensitivity, acne", comedogenic_rating: 0
  },
  {
    name: "Clay Mask Treatment", brand: "Origins", category: "spot_treatment", price: 34.00,
    key_ingredients: "white china clay, lecithin", skin_concerns: "oiliness, acne", comedogenic_rating: 1
  },
  {
    name: "Gentle Milk Cleanser", brand: "Avène", category: "cleanser", price: 20.00,
    key_ingredients: "thermal spring water, pre-tocopheryl", skin_concerns: "sensitivity, dryness", comedogenic_rating: 0
  },
  {
    name: "Lactic Acid 10% + HA", brand: "The Ordinary", category: "serum", price: 7.90,
    key_ingredients: "lactic acid, hyaluronic acid", skin_concerns: "hyperpigmentation, dryness", comedogenic_rating: 0
  },
  {
    name: "Barrier Repair Moisturizer", brand: "Stratia", category: "moisturizer", price: 14.00,
    key_ingredients: "ceramides, cholesterol, fatty acids", skin_concerns: "dryness, sensitivity", comedogenic_rating: 0
  },
  {
    name: "Sheer Zinc SPF 50", brand: "Cotz", category: "sunscreen", price: 21.99,
    key_ingredients: "zinc oxide, titanium dioxide", skin_concerns: "sensitivity, acne", comedogenic_rating: 0
  },
  {
    name: "Charcoal Mask", brand: "Freeman", category: "spot_treatment", price: 3.99,
    key_ingredients: "charcoal, clay", skin_concerns: "oiliness, acne", comedogenic_rating: 1
  }
]

# Create products with default values
products_data.each_with_index do |product_data, index|
  # Add default values
  product_data[:currency] ||= 'USD'
  product_data[:product_url] ||= "https://example.com/#{product_data[:brand].downcase.gsub(' ', '-')}-#{product_data[:name].downcase.gsub(' ', '-')}"
  product_data[:image_url] ||= "https://example.com/#{product_data[:brand].downcase.gsub(' ', '-')}-#{product_data[:name].downcase.gsub(' ', '-')}.jpg"
  
  begin
    product = Product.create!(product_data)
    puts "Created product #{index + 1}/#{products_data.length}: #{product.brand} #{product.name}"
  rescue => e
    puts "Error creating product: #{e.message}"
    puts "Product data: #{product_data}"
  end
end

puts "Seeding completed! Created #{Product.count} products across #{Product.distinct.count(:category)} categories."
puts "Categories: #{Product.distinct.pluck(:category).join(', ')}"
puts "Brands: #{Product.distinct.count(:brand)} unique brands"
