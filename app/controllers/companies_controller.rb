class CompaniesController < ApplicationController
  before_action :require_admin

  def edit
    @company = current_company
  end

  def update
    @company = current_company
    was_ai = @company.ai_job_matching?
    was_rules = @company.match_rules
    if @company.update(company_params)
      audit("company.updated", subject: @company, summary: "Updated company settings")
      if @company.match_rules != was_rules
        SwapMatcher.new(@company).refresh_all
        audit("company.match_rules", summary: "Matching rules: #{@company.rules.describe.join("; ").presence || "none"}")
      elsif @company.ai_job_matching? && !was_ai
        SwapMatcher.new(@company).refresh_all
        audit("company.ai_matching", summary: "Turned on AI job matching")
      elsif was_ai && !@company.ai_job_matching?
        audit("company.ai_matching", summary: "Turned off AI job matching")
      end
      redirect_to edit_company_path, notice: "Company settings saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def company_params
    permitted = params.require(:company).permit(:name, :ai_job_matching,
                                                match_rules: %i[min_seniority max_seniority_gap same_job_code_only same_fields])
    permitted[:match_rules] = permitted[:match_rules].to_h if permitted.key?(:match_rules)
    permitted
  end
end
