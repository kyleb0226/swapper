# A company asking for matching built around its own rules ("only swap within
# the same union local", "nurses need the same unit certification", …).
# Sent from the public home page / custom page; worked by the platform owner
# in /admin/custom_requests.
class CustomRequest < ApplicationRecord
  STATUSES = %w[new contacted quoted building done declined].freeze
  SIZES = [ "Under 100", "100–500", "500–2,000", "2,000–10,000", "10,000+" ].freeze

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :name, :organization, with: ->(value) { value.squish }

  validates :name, :organization, presence: true, length: { maximum: 120 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 200 }
  validates :message, presence: true, length: { maximum: 5_000 }
  validates :employee_count, inclusion: { in: SIZES }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :open, -> { where.not(status: %w[done declined]) }
end
