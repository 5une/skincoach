class Consultation < ApplicationRecord
  # Status values as defined in CURSOR.md
  STATUSES = %w[pending analyzing completed failed].freeze

  # Active Storage for uploaded photo
  has_one_attached :photo

  validates :status, inclusion: { in: STATUSES }
  validates :photo, presence: true

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :analyzing, -> { where(status: 'analyzing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }

  # Status check methods
  def pending?
    status == 'pending'
  end

  def analyzing?
    status == 'analyzing'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def processing?
    pending? || analyzing?
  end

  # Analysis data helpers
  def face_detected?
    analysis_data&.dig('face_detected') == true
  end

  def skin_type
    analysis_data&.dig('skin_type')
  end

  def concerns
    analysis_data&.dig('concerns') || []
  end

  def severity
    analysis_data&.dig('severity') || {}
  end

  def notes
    analysis_data&.dig('notes')
  end

  # Recommendation data helpers
  def product_picks
    recommendations_data&.dig('picks') || {}
  end

  def rationale
    recommendations_data&.dig('rationale')
  end
end
