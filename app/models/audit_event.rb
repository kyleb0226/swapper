class AuditEvent < ApplicationRecord
  belongs_to :company, optional: true
  belongs_to :user, optional: true

  scope :recent, -> { order(created_at: :desc) }

  def self.record(action, subject: nil, summary: nil, user: Current.user, company: Current.company)
    create!(action: action, subject_type: subject&.class&.name, subject_id: subject&.id,
            summary: summary, user: user, company: company)
  end
end
