class Employee < ApplicationRecord
  belongs_to :company
  belongs_to :user, optional: true
  belongs_to :current_location, class_name: "Location"
  belongs_to :desired_location, class_name: "Location", optional: true

  has_many :matches, dependent: :destroy
  has_many :reverse_matches, class_name: "Match", foreign_key: :matched_employee_id, dependent: :destroy

  normalizes :name, :job_title, :job_code, with: ->(value) { value.squish }
  normalizes :email, with: ->(email) { email.strip.downcase.presence }

  validates :name, :job_title, presence: true
  validates :seniority, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 100 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :email, uniqueness: { scope: :company_id, case_sensitive: false }, allow_blank: true
  validate :locations_belong_to_company
  validate :desired_location_differs

  before_save :track_swap_request

  scope :ordered, -> { order(:name) }
  scope :seeking, -> { where.not(desired_location_id: nil) }

  def seeking_swap?
    desired_location_id.present?
  end

  def all_matches
    Match.involving(self)
  end

  def active_match
    all_matches.where(status: %w[pending approved]).order(Arel.sql("CASE status WHEN 'approved' THEN 0 ELSE 1 END")).first
  end

  def locked_in_swap?
    all_matches.approved.exists?
  end

  private

  def locations_belong_to_company
    errors.add(:current_location, "must be one of your company's locations") if current_location && current_location.company_id != company_id
    errors.add(:desired_location, "must be one of your company's locations") if desired_location && desired_location.company_id != company_id
  end

  def desired_location_differs
    if desired_location_id.present? && desired_location_id == current_location_id
      errors.add(:desired_location, "can't be the same as the current location")
    end
  end

  def track_swap_request
    if desired_location_id_changed?
      self.swap_requested_at = desired_location_id.present? ? Time.current : nil
    end
  end
end
