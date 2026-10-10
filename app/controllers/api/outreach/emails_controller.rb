module Api
  module Outreach
    class EmailsController < BaseController
      def index
        emails = ::Outreach::Email.includes(:prospect).recent.limit(params.fetch(:limit, 100).to_i.clamp(1, 500))
        render json: {
          emails: emails.map do |email|
            email.as_json(only: %i[id to subject status error sent_at created_at])
                 .merge("prospect_id" => email.prospect_id, "organization" => email.prospect.organization)
          end
        }
      end
    end
  end
end
