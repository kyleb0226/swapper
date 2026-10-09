module Admin
  class CompaniesController < BaseController
    def index
      @companies = Company.order(created_at: :desc)
      @user_counts = User.group(:company_id).count
      @employee_counts = Employee.group(:company_id).count
      @swap_counts = Match.completed.group(:company_id).count
    end

    def show
      @company = Company.find(params[:id])
      @users = @company.users.order(:role, :email)
      @match_counts = @company.matches.group(:status).count
    end
  end
end
