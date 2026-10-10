module Api
  module Outreach
    # Lets an agent check what it's allowed to do before it starts.
    class StatusController < BaseController
      def show
        render json: {
          can_send: ::Outreach.api_can_send? && ::Outreach.configuration_problems.empty?,
          send_enabled_for_api: ::Outreach.api_can_send?,
          configuration_problems: ::Outreach.configuration_problems,
          daily_limit: ::Outreach.daily_limit,
          sent_today: ::Outreach.sent_today,
          remaining_today: [ ::Outreach.daily_limit - ::Outreach.sent_today, 0 ].max,
          prospect_statuses: ::Outreach::Prospect::STATUSES,
          sectors: ::Outreach::Prospect::SECTORS
        }
      end
    end
  end
end
