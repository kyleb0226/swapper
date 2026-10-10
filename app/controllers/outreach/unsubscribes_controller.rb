module Outreach
  # Public, no login: the opt-out link at the bottom of every outreach email.
  # POST supports one-click unsubscribe (RFC 8058) from mail clients.
  class UnsubscribesController < ApplicationController
    skip_forgery_protection only: :create
    before_action :set_prospect

    def show
    end

    def create
      if @prospect && !@prospect.unsubscribed?
        @prospect.update!(unsubscribed_at: Time.current)
        Suppression.record!(@prospect.email, "unsubscribed") if @prospect.email.present?
      end
      render :show
    end

    private

    def set_prospect
      @prospect = Prospect.find_by_token_for(:unsubscribe, params[:token])
    end
  end
end
