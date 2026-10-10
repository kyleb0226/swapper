module Outreach
  class EmailTemplate < ApplicationRecord
    MERGE_TAG = /\{\{\s*(\w+)\s*\}\}/

    has_many :emails, dependent: :nullify

    validates :name, :subject, :body, presence: true

    scope :ordered, -> { order(:name) }

    def render_for(prospect)
      fields = prospect.merge_fields
      fill = ->(text) { text.gsub(MERGE_TAG) { fields.fetch($1, "") } }
      { subject: fill.(subject), body: fill.(body) }
    end
  end
end
