module Admin
  class DashboardController < BaseController
    def show
      @stats = {
        companies: Company.count, users: User.where.not(company_id: nil).count, employees: Employee.count,
        completed_swaps: Match.completed.count, prospects: ::Outreach::Prospect.count,
        emails_sent: ::Outreach::Email.where(status: "sent").count
      }
      @recent_companies = Company.order(created_at: :desc).limit(5)
      @pipeline = ::Outreach::Prospect.group(:status).count
    end
  end
end
