module Admin
  module Outreach
    class EmailsController < BaseController
      def index
        @emails = ::Outreach::Email.includes(:prospect).recent.limit(200)
        @sent_today = ::Outreach.sent_today
      end

      def show
        @email = ::Outreach::Email.find(params[:id])
      end
    end
  end
end
