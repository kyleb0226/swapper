module Admin
  module Outreach
    # The permanent do-not-contact list. People are added automatically when
    # they're emailed, unsubscribe or bounce; you can add addresses or whole
    # domains (e.g. an existing customer's) by hand.
    class SuppressionsController < BaseController
      def index
        scope = ::Outreach::Suppression.recent
        scope = scope.where("email LIKE :q OR domain LIKE :q OR note LIKE :q", q: "%#{::Outreach::Suppression.sanitize_sql_like(params[:q])}%") if params[:q].present?
        scope = scope.where(reason: params[:reason]) if ::Outreach::Suppression::REASONS.include?(params[:reason])
        @suppressions = scope.limit(500)
        @counts = ::Outreach::Suppression.group(:reason).count
        @suppression = ::Outreach::Suppression.new(reason: "manual")
      end

      def create
        value = params.dig(:outreach_suppression, :value).to_s.strip
        attrs = value.include?("@") ? { email: value } : { domain: value }
        @suppression = ::Outreach::Suppression.new(attrs.merge(reason: params.dig(:outreach_suppression, :reason).presence || "manual",
                                                               note: params.dig(:outreach_suppression, :note)))
        if @suppression.save
          redirect_to admin_outreach_suppressions_path, notice: "#{value} won't be emailed."
        else
          redirect_to admin_outreach_suppressions_path, alert: @suppression.errors.full_messages.to_sentence
        end
      end

      def destroy
        suppression = ::Outreach::Suppression.find(params[:id])
        if suppression.reason == "unsubscribed"
          redirect_to admin_outreach_suppressions_path, alert: "People who unsubscribed can't be removed from the list."
        else
          suppression.destroy
          redirect_to admin_outreach_suppressions_path, notice: "#{suppression.email || suppression.domain} removed from the list."
        end
      end
    end
  end
end
