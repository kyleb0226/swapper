module Outreach
  class DeliveryJob < ApplicationJob
    queue_as :default

    def perform(email)
      return unless email.status == "queued"

      if email.prospect.unsubscribed?
        email.update!(status: "skipped", error: "Prospect unsubscribed")
        return
      end

      ProspectMailer.with(email: email).outreach.deliver_now
      email.update!(status: "sent", sent_at: Time.current, error: nil)
      prospect = email.prospect
      prospect.update!(last_contacted_at: Time.current, status: prospect.status == "new" ? "contacted" : prospect.status)
    rescue StandardError => e
      email.update!(status: "failed", error: e.message.truncate(500))
    end
  end
end
