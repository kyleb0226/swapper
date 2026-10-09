module Outreach
  class Email < ApplicationRecord
    STATUSES = %w[queued sent failed skipped].freeze

    belongs_to :prospect
    belongs_to :email_template, optional: true

    validates :to, :subject, :body, presence: true
    validates :status, inclusion: { in: STATUSES }

    scope :recent, -> { order(created_at: :desc) }
  end
end
