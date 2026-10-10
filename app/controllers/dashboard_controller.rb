class DashboardController < ApplicationController
  before_action :require_manager

  def show
    employees = current_company.employees
    matches = current_company.matches
    @stats = {
      employees: employees.count,
      seeking: employees.seeking.count,
      pending: matches.pending.count,
      approved: matches.approved.count,
      completed: matches.completed.count
    }
    @locations_count = current_company.locations.count
    @pending_matches = matches.pending.includes(employee: :current_location, matched_employee: :current_location)
                              .order(created_at: :desc).limit(5)
    @top_destinations = employees.seeking.joins(:desired_location)
                                 .group("locations.name").order(Arel.sql("COUNT(*) DESC")).limit(5).count
    @recent_events = current_company.audit_events.includes(:user).recent.limit(8) if Current.user.admin?
  end
end
