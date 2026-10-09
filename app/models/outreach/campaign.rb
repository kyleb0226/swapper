module Outreach
  # Queues one personalized email per selected prospect. Sends are staggered so
  # a batch doesn't look like a blast to spam filters, and capped per day.
  class Campaign
    SPACING = 45.seconds
    # Never email the same prospect twice in this window (protects against
    # double-clicks and AI agents re-running the same batch).
    RECENT_CONTACT_WINDOW = 3.days

    Result = Struct.new(:queued, :skipped, :errors)

    def initialize(template:, prospects:)
      @template = template
      @prospects = prospects
    end

    def send!
      result = Result.new(0, 0, [])
      problems = Outreach.configuration_problems
      if problems.any?
        result.errors.concat(problems)
        return result
      end

      remaining = Outreach.daily_limit - Outreach.sent_today
      @prospects.each do |prospect|
        if prospect.email.blank? || prospect.unsubscribed? || recently_emailed?(prospect)
          result.skipped += 1
          next
        end
        if remaining <= 0
          result.errors << "Daily limit of #{Outreach.daily_limit} reached; the rest were not queued. Send them tomorrow."
          break
        end

        content = @template.render_for(prospect)
        email = prospect.emails.create!(email_template: @template, to: prospect.email, **content)
        DeliveryJob.set(wait: SPACING * result.queued).perform_later(email)
        result.queued += 1
        remaining -= 1
      end
      result
    end

    private

    def recently_emailed?(prospect)
      prospect.emails.where(status: %w[queued sent]).where(created_at: RECENT_CONTACT_WINDOW.ago..).exists?
    end
  end
end
