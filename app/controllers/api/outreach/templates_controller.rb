module Api
  module Outreach
    class TemplatesController < BaseController
      def index
        render json: { templates: ::Outreach::EmailTemplate.ordered.map { |t| t.as_json(only: %i[id name subject body]) } }
      end
    end
  end
end
