# Runs AI job comparisons in the background, then re-runs swap matching for
# everyone holding one of the compared jobs so new "similar job" matches appear.
class JobComparisonJob < ApplicationJob
  queue_as :default

  def perform(company, pairs)
    return unless company.ai_job_matching? && JobComparer.available?

    JobComparer.new(company).compare(pairs)
    SwapMatcher.new(company).refresh_titles(pairs.flatten.uniq)
  end
end
