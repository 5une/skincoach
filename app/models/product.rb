class Product < ApplicationRecord
  # Categories as defined in CURSOR.md
  CATEGORIES = %w[cleanser serum moisturizer sunscreen spot_treatment].freeze
  
  # Skin concerns from CURSOR.md
  SKIN_CONCERNS = %w[acne redness dryness oiliness hyperpigmentation sensitivity].freeze

  validates :name, presence: true
  validates :brand, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :comedogenic_rating, numericality: { 
    greater_than_or_equal_to: 0, 
    less_than_or_equal_to: 5, 
    allow_nil: true 
  }

  # Scopes for filtering products
  scope :by_category, ->(category) { where(category: category) }
  scope :by_concerns, ->(concerns) { 
    concerns_array = Array(concerns)
    where("skin_concerns LIKE ?", "%#{concerns_array.join('%')}%")
  }
  scope :low_comedogenic, -> { where('comedogenic_rating <= ? OR comedogenic_rating IS NULL', 2) }
  scope :fragrance_free, -> { where("key_ingredients NOT LIKE ? OR key_ingredients IS NULL", "%fragrance%") }

  # Helper method to get skin concerns as array
  def skin_concerns_array
    return [] if skin_concerns.blank?
    skin_concerns.split(',').map(&:strip)
  end

  # Helper method to get key ingredients as array
  def key_ingredients_array
    return [] if key_ingredients.blank?
    key_ingredients.split(',').map(&:strip)
  end

  # Check if product is suitable for acne-prone skin
  def acne_friendly?
    comedogenic_rating.nil? || comedogenic_rating <= 2
  end

  # Check if product is fragrance-free
  def fragrance_free?
    return true if key_ingredients.blank?
    !key_ingredients.downcase.include?('fragrance')
  end
end
