module Admin
  module Outreach
    # Compose -> preview -> send. Nothing is sent until the preview is confirmed.
    class CampaignsController < BaseController
      before_action :load_choices

      def new
        @selected_ids = Array(params[:prospect_ids]).map(&:to_i)
      end

      def preview
        @template = ::Outreach::EmailTemplate.find_by(id: params[:template_id])
        @selected = selected_prospects
        if @template.nil? || @selected.empty?
          flash.now[:alert] = "Pick a template and at least one prospect."
          @selected_ids = @selected.map(&:id)
          render :new, status: :unprocessable_entity
          return
        end
        @samples = @selected.first(3).map { |prospect| [ prospect, @template.render_for(prospect) ] }
        @problems = ::Outreach.configuration_problems
      end

      def create
        template = ::Outreach::EmailTemplate.find(params[:template_id])
        result = ::Outreach::Campaign.new(template: template, prospects: selected_prospects).send!
        message = "Queued #{result.queued} #{"email".pluralize(result.queued)}."
        message += " Skipped #{result.skipped} (no email or unsubscribed)." if result.skipped.positive?
        if result.errors.any?
          redirect_to admin_outreach_emails_path, alert: [ message, *result.errors ].join(" ")
        else
          redirect_to admin_outreach_emails_path, notice: message
        end
      end

      private

      def load_choices
        @templates = ::Outreach::EmailTemplate.ordered
        @prospects = ::Outreach::Prospect.emailable.ordered.limit(500)
      end

      def selected_prospects
        ::Outreach::Prospect.emailable.where(id: Array(params[:prospect_ids])).ordered.to_a
      end
    end
  end
end
