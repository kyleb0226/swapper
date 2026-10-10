module Admin
  module Outreach
    class LeadSourcesController < BaseController
      def show
        @sources = ::Outreach::LeadSources.all
        @sector = params[:sector].presence
        @region = params[:region].to_s.strip
        @searches = ::Outreach::LeadSources.searches(sector: @sector, region: @region) if @sector
      end
    end
  end
end
