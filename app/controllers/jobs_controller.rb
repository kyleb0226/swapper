# Lists every job title in the company so HR can describe it, and shows how the
# AI has judged pairs of different jobs.
class JobsController < ApplicationController
  before_action :require_admin

  def index
    counts = current_company.employees.group("LOWER(job_title)").count
    titles = current_company.employees.distinct.pluck(:job_title).index_by { |title| JobProfile.key_for(title) }
    profiles = current_company.job_profiles.index_by(&:title_key)
    @jobs = titles.map do |key, title|
      { key: key, title: profiles[key]&.title || title, description: profiles[key]&.description, count: counts[key].to_i }
    end.sort_by { |job| job[:title].downcase }
    @similarities = current_company.job_similarities.ordered
    @titles = @jobs.to_h { |job| [ job[:key], job[:title] ] }
  end

  def describe
    key = JobProfile.key_for(params[:title])
    profile = current_company.job_profiles.find_or_initialize_by(title_key: key)
    profile.title = params[:title].to_s.squish
    profile.description = params[:description].to_s.strip.presence
    if profile.save
      audit("job.described", summary: "Updated the description of #{profile.title}")
      SwapMatcher.new(current_company).refresh_titles([ key ]) if current_company.ai_job_matching?
      redirect_to jobs_path, notice: "Saved. Comparisons involving #{profile.title} will be re-checked."
    else
      redirect_to jobs_path, alert: profile.errors.full_messages.to_sentence
    end
  end
end
