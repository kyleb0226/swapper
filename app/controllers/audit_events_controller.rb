class AuditEventsController < ApplicationController
  PER_PAGE = 50

  before_action :require_admin

  def index
    @page = [ params[:page].to_i, 1 ].max
    @events = current_company.audit_events.includes(:user).recent.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    @next_page = @events.size > PER_PAGE
    @events = @events.first(PER_PAGE)
  end
end
