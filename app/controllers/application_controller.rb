class ApplicationController < ActionController::Base
  before_action :set_current_user

  helper_method :signed_in?, :current_company

  private

  def set_current_user
    Current.user = User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def signed_in?
    Current.user.present?
  end

  def current_company
    Current.company
  end

  def sign_in(user)
    reset_session # prevents session fixation
    session[:user_id] = user.id
    user.update_column(:last_sign_in_at, Time.current)
    Current.user = user
  end

  def home_path_for(user)
    if user.company.nil? then admin_root_path
    elsif user.manager? then dashboard_path
    else my_request_path
    end
  end

  def require_sign_in
    return if signed_in?

    session[:return_to] = request.fullpath if request.get?
    redirect_to sign_in_path, alert: "Please sign in first."
  end

  def require_company
    require_sign_in
    return if performed? || current_company

    redirect_to admin_root_path
  end

  def require_manager
    require_role(:manager)
  end

  def require_admin
    require_role(:admin)
  end

  def require_role(role)
    require_company
    return if performed? || Current.user.role_at_least?(role)

    redirect_to home_path_for(Current.user), alert: "You don't have access to that page."
  end

  def audit(action, subject: nil, summary: nil)
    AuditEvent.record(action, subject: subject, summary: summary)
  end
end
