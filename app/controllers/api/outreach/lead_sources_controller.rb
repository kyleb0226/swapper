module Api
  module Outreach
    class LeadSourcesController < BaseController
      def show
        payload = { sources: ::Outreach::LeadSources.all.map(&:to_h) }
        if params[:sector].present?
          payload[:searches] = ::Outreach::LeadSources.searches(sector: params[:sector], region: params[:region].to_s)
                                                      .map { |label, url| { label: label, url: url } }
        end
        render json: payload
      end
    end
  end
end
