# Only the platform owner (users flagged platform_admin) can reach /admin.
module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :require_sign_in
    before_action :require_platform_admin

    private

    def require_platform_admin
      return if performed? || Current.user.platform_admin?

      redirect_to home_path_for(Current.user), alert: "You don't have access to that page."
    end
  end
end
