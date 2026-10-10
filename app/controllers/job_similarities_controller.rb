# HR's final say over whether two jobs can swap. Overrides are never changed by the AI.
class JobSimilaritiesController < ApplicationController
  before_action :require_admin
  before_action :set_similarity

  def override
    similar = params[:similar] == "1"
    @similarity.update!(source: "manual", similar: similar, status: "done",
                        reason: "Set by #{Current.user.display_name}", compared_at: Time.current)
    audit("job.similarity_override", summary: "Marked #{@similarity.job_a} and #{@similarity.job_b} as #{similar ? "similar" : "not similar"}")
    SwapMatcher.new(current_company).refresh_titles([ @similarity.job_a, @similarity.job_b ])
    redirect_to jobs_path, notice: "Saved. Matches have been updated."
  end

  # Clears an override or a failed result and asks the AI again.
  def recheck
    @similarity.update!(source: "ai", status: "pending", fingerprint: nil, requested_at: nil, similar: nil, score: nil, reason: nil)
    SwapMatcher.new(current_company).refresh_titles([ @similarity.job_a, @similarity.job_b ])
    redirect_to jobs_path, notice: "Queued for a fresh AI check."
  end

  private

  def set_similarity
    @similarity = current_company.job_similarities.find(params[:id])
  end
end
