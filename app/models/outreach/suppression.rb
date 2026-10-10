module Outreach
  # One row per address (or whole domain) that must not get another automatic email.
  class Suppression < ApplicationRecord
    # Strongest first: a weaker reason never overwrites a stronger one.
    REASONS = %w[unsubscribed bounced manual customer contacted].freeze
    LABELS = {
      "unsubscribed" => "Unsubscribed", "bounced" => "Bounced", "manual" => "Blocked by you",
      "customer" => "Existing customer", "contacted" => "Already contacted"
    }.freeze

    normalizes :email, with: ->(email) { email.strip.downcase.presence }
    normalizes :domain, with: ->(domain) { Outreach::Suppression.clean_domain(domain) }

    validates :reason, inclusion: { in: REASONS }
    validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
    validates :domain, uniqueness: true, allow_nil: true
    validate :email_or_domain

    scope :recent, -> { order(created_at: :desc) }

    def self.clean_domain(value)
      text = value.to_s.strip.downcase
      text = text.split("@").last if text.include?("@")
      text.sub(%r{\Ahttps?://}, "").sub(/\Awww\./, "").split("/").first.presence
    end

    def self.for_email(email)
      return if email.blank?

      address = email.strip.downcase
      find_by(email: address) || find_by(domain: address.split("@").last)
    end

    # Adds or strengthens a block. Returns [suppression, created?].
    def self.record!(email, reason, note: nil)
      row = find_or_initialize_by(email: email.to_s.strip.downcase)
      created = row.new_record?
      if created || REASONS.index(reason) < REASONS.index(row.reason)
        row.update!(reason: reason, note: note || row.note)
      end
      [ row, created ]
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    def label = LABELS.fetch(reason)
    def blocks_follow_ups? = reason != "contacted"

    private

    def email_or_domain
      errors.add(:base, "Enter an email address or a domain") if email.blank? && domain.blank?
    end
  end
end
