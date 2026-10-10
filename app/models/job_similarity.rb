require "digest"

# Cached answer to "can someone in job A swap with someone in job B?" for one
# company. Pairs are stored once (job_a < job_b). The fingerprint covers both
# jobs' titles and HR descriptions, so the AI is asked again only when one of
# the two jobs changes. HR overrides (source "manual") are never recomputed.
class JobSimilarity < ApplicationRecord
  PROMPT_VERSION = "1"
  THRESHOLD = 70
  RETRY_AFTER = 1.hour

  belongs_to :company

  validates :status, inclusion: { in: %w[pending done failed] }
  validates :source, inclusion: { in: %w[ai manual] }

  scope :ordered, -> { order(:job_a, :job_b) }

  def self.pair(title_a, title_b)
    [ JobProfile.key_for(title_a), JobProfile.key_for(title_b) ].sort
  end

  def self.lookup(company, title_a, title_b)
    job_a, job_b = pair(title_a, title_b)
    company.job_similarities.find_by(job_a: job_a, job_b: job_b)
  end

  def self.fingerprint_for(company, job_a, job_b)
    descriptions = company.job_profiles.where(title_key: [ job_a, job_b ]).pluck(:title_key, :description).to_h
    Digest::SHA256.hexdigest([ PROMPT_VERSION, job_a, descriptions[job_a].to_s.squish, job_b, descriptions[job_b].to_s.squish ].join("\u0001"))
  end

  def manual? = source == "manual"

  def fresh?
    manual? || fingerprint == self.class.fingerprint_for(company, job_a, job_b)
  end

  # Good enough to propose a new swap: an HR override, or a current AI answer.
  def approves_new_match?
    manual? ? similar? : (status == "done" && similar? && fresh?)
  end

  # Good enough to keep an existing match while a changed job is re-checked.
  def keeps_existing_match?
    similar? && (manual? || status != "failed")
  end

  # Whether the AI should be asked (again) about this pair.
  # Done answers are re-asked only when a job changed; pending or failed ones
  # are retried at most once per RETRY_AFTER so an outage can't cause a loop.
  def needs_comparison?
    return false if manual?
    return !fresh? if status == "done"

    requested_at.nil? || requested_at < RETRY_AFTER.ago
  end
end
