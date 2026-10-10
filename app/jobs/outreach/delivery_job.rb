module Outreach
  class DeliveryJob < ApplicationJob
    queue_as :default

    BOUNCE = /\b(550|551|553|554)\b|user unknown|no such user|does not exist|mailbox unavailable|invalid recipient/i

    def perform(email)
      return unless email.status == "queued"

      if (reason = claim_or_block(email))
        email.update!(status: "skipped", error: reason)
        return
      end

      ProspectMailer.with(email: email).outreach.deliver_now
      email.update!(status: "sent", sent_at: Time.current, error: nil)
      prospect = email.prospect
      prospect.update!(last_contacted_at: Time.current, status: prospect.status == "new" ? "contacted" : prospect.status)
    rescue StandardError => e
      email.update!(status: "failed", error: e.message.truncate(500))
      Suppression.record!(email.to, "bounced", note: e.message.truncate(200)) if e.message.match?(BOUNCE)
    end

    private

    # Last check right before sending. Adding the address to the do-not-contact
    # list is the lock: if two batches queued the same person, only the first
    # one to get here sends.
    def claim_or_block(email)
      return "Prospect unsubscribed" if email.prospect.unsubscribed?

      existing = Suppression.for_email(email.to)
      if email.follow_up
        return "On do-not-contact list: #{existing.label.downcase}" if existing&.blocks_follow_ups?

        Suppression.record!(email.to, "contacted")
        nil
      else
        return "On do-not-contact list: #{existing.label.downcase}" if existing

        _row, created = Suppression.record!(email.to, "contacted", note: email.prospect.organization)
        created ? nil : "Already contacted"
      end
    end
  end
end
