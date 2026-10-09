module Api
  module Outreach
    # Queues emails. Off unless OUTREACH_API_ALLOW_SEND=1; the same safety rules
    # as the admin UI apply (postal address, unsubscribes, daily cap, no repeats).
    class CampaignsController < BaseController
      def create
        unless ::Outreach.api_can_send?
          render json: { error: "Sending through the API is turned off (set OUTREACH_API_ALLOW_SEND=1). " \
                                "Add prospects and leave sending to the owner in the admin UI." }, status: :forbidden
          return
        end

        template = ::Outreach::EmailTemplate.find(params.require(:template_id))
        prospects = ::Outreach::Prospect.emailable.where(id: Array(params.require(:prospect_ids))).to_a
        result = ::Outreach::Campaign.new(template: template, prospects: prospects).send!
        status = result.queued.zero? && result.errors.any? ? :unprocessable_entity : :ok
        render json: { queued: result.queued, skipped: result.skipped, errors: result.errors }, status: status
      end
    end
  end
end
