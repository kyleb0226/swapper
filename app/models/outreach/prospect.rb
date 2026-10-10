module Outreach
  class Prospect < ApplicationRecord
    STATUSES = %w[new contacted replied meeting customer not_interested].freeze
    SECTORS = [
      "Healthcare system", "Public school district", "State agency", "County / city government",
      "Federal agency", "Corrections / public safety", "Transit / transportation", "Retail / grocery chain",
      "Bank / credit union", "Logistics / warehousing", "Hospitality", "Staffing agency", "Other"
    ].freeze

    has_many :emails, dependent: :destroy

    normalizes :email, with: ->(email) { email.strip.downcase.presence }

    validates :organization, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true, allow_nil: true

    scope :ordered, -> { order(:organization) }
    scope :subscribed, -> { where(unsubscribed_at: nil) }
    scope :emailable, -> { subscribed.where.not(email: nil).where.not(status: %w[customer not_interested]) }

    generates_token_for :unsubscribe

    def unsubscribed? = unsubscribed_at.present?

    def suppression = Suppression.for_email(email)

    # nil when a first email may go out, otherwise why not.
    def contact_blocked_reason = ContactPolicy.new.blocked_reason(self)

    def first_name
      contact_name.to_s.split.first.presence || "there"
    end

    # Values available as {{merge_tags}} in templates.
    def merge_fields
      {
        "first_name" => first_name, "contact_name" => contact_name.presence || "there",
        "organization" => organization, "title" => contact_title.to_s,
        "city" => city.to_s, "state" => state.to_s, "sector" => sector.to_s
      }
    end
  end
end
