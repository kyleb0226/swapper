module Api
  module Outreach
    # Token-authenticated JSON API so an external AI agent can research leads,
    # manage prospects and (optionally) send outreach. Every request needs
    # "Authorization: Bearer <OUTREACH_API_TOKEN>".
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "Not found" }, status: :not_found
      end
      rescue_from ActionController::ParameterMissing do |e|
        render json: { error: e.message }, status: :bad_request
      end

      private

      def authenticate
        expected = ::Outreach.api_token
        if expected.nil?
          render json: { error: "The outreach API is turned off. Set OUTREACH_API_TOKEN to enable it." }, status: :service_unavailable
          return
        end

        authenticate_or_request_with_http_token do |token, _options|
          ActiveSupport::SecurityUtils.secure_compare(token, expected)
        end
      end

      def prospect_json(prospect)
        prospect.as_json(only: %i[id organization contact_name contact_title email phone website sector city state
                                  source status notes last_contacted_at created_at])
                .merge("unsubscribed" => prospect.unsubscribed?)
      end
    end
  end
end
