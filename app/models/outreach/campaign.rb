module Outreach
  # Queues one personalized email per selected prospect. Sends are staggered so
  # a batch doesn't look like a blast to spam filters, and capped per day.
  # Who may be emailed is decided by ContactPolicy.
  class Campaign
    SPACING = 45.seconds

    Result = Struct.new(:queued, :skipped, :errors, :skipped_reasons)

    def initialize(template:, prospects:, follow_up: false)
      @template = template
      @prospects = prospects
      @follow_up = follow_up
    end

    def send!
      result = Result.new(0, 0, [], {})
      problems = Outreach.configuration_problems
      if problems.any?
        result.errors.concat(problems)
        return result
      end

      policy = ContactPolicy.new(follow_up: @follow_up)
      remaining = Outreach.daily_limit - Outreach.sent_today
      claimed = []
      @prospects.each do |prospect|
        if (reason = policy.blocked_reason(prospect, also_claimed: claimed))
          result.skipped += 1
          result.skipped_reasons[prospect.organization] = reason
          next
        end
        if remaining <= 0
          result.errors << "Daily limit of #{Outreach.daily_limit} reached; the rest were not queued. Send them tomorrow."
          break
        end

        content = @template.render_for(prospect)
        email = prospect.emails.create!(email_template: @template, to: prospect.email, follow_up: @follow_up, **content)
        DeliveryJob.set(wait: SPACING * result.queued).perform_later(email)
        claimed << prospect
        result.queued += 1
        remaining -= 1
      end
      result
    end
  end
end
