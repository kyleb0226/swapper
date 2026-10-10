class CompaniesController < ApplicationController
  before_action :require_admin

  def edit
    @company = current_company
  end

  def update
    @company = current_company
    was_ai = @company.ai_job_matching?
    if @company.update(params.require(:company).permit(:name, :ai_job_matching))
      audit("company.updated", subject: @company, summary: "Updated company settings")
      if @company.ai_job_matching? && !was_ai
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
end
