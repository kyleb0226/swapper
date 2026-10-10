# HR's description of a job title. Descriptions make AI job matching more
# accurate; editing one makes every comparison involving that job re-run.
class JobProfile < ApplicationRecord
  belongs_to :company

  validates :title, :title_key, presence: true
  validates :title_key, uniqueness: { scope: :company_id }
  validates :description, length: { maximum: 2000 }

  def self.key_for(title) = title.to_s.squish.downcase
end
