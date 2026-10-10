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

    # The owner assigns a bespoke rule (or adjusts standard ones) for a customer.
    def update
      @company = Company.find(params[:id])
      rules = params.require(:company).permit(:custom_rule, match_rules: %i[min_seniority max_seniority_gap same_job_code_only same_fields])
      attrs = { custom_rule: rules[:custom_rule].presence }
      attrs[:match_rules] = rules[:match_rules].to_h if rules.key?(:match_rules)
      if @company.update(attrs)
        SwapMatcher.new(@company).refresh_all
        redirect_to admin_company_path(@company), notice: "Matching rules saved and matching re-run."
      else
        redirect_to admin_company_path(@company), alert: @company.errors.full_messages.to_sentence
      end
    end
  end
end
