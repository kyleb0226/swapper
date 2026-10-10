class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :locations, dependent: :destroy
  has_many :employees, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_many :audit_events, dependent: :destroy
  has_many :job_profiles, dependent: :destroy
  has_many :job_similarities, dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
  validates :custom_rule, inclusion: { in: ->(_) { MatchRules::Custom.keys } }, allow_blank: true

  normalizes :match_rules, with: ->(rules) { MatchRules.clean(rules) }

  def rules
    MatchRules.new(self)
  end
end
