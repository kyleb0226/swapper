class CompaniesController < ApplicationController
  before_action :require_admin

  def edit
    @company = current_company
  end

  def update
    @company = current_company
    if @company.update(params.require(:company).permit(:name))
      audit("company.updated", subject: @company, summary: "Renamed workspace to #{@company.name}")
      redirect_to edit_company_path, notice: "Company settings saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
