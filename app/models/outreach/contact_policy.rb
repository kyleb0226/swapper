module Outreach
  # The single place that decides whether a prospect may be emailed.
  #
  # Rules:
  #   * never email anyone on the do-not-contact list (everyone emailed once is added automatically)
  #   * one person per organization: once someone at a company was emailed, skip their colleagues
  #   * never email customers or prospects marked not interested
  #   * follow-ups (a second email to the same person) only when the owner explicitly asks for one
  #     in the admin UI, never through the API, and never sooner than FOLLOW_UP_GAP
  class ContactPolicy
    FOLLOW_UP_GAP = 3.days
    COLLEAGUE_WINDOW = 180.days
    # Personal email providers: sharing one says nothing about the organization.
    FREEMAIL = %w[gmail.com googlemail.com yahoo.com outlook.com hotmail.com live.com msn.com aol.com icloud.com
                  me.com proton.me protonmail.com gmx.com mail.com yandex.com zoho.com].freeze

    def self.org_domain(email)
      domain = email.to_s.downcase.split("@").last
      domain unless domain.blank? || FREEMAIL.include?(domain)
    end

    def self.org_key(name)
      name.to_s.downcase.gsub(/[^a-z0-9 ]/, " ").gsub(/\b(the|inc|llc|corp|corporation|co|company)\b/, " ").squish.presence
    end

    def initialize(follow_up: false)
      @follow_up = follow_up
    end

    # nil when the prospect may be emailed, otherwise a short reason.
    def blocked_reason(prospect, also_claimed: [])
      return "no email address" if prospect.email.blank?
      return "unsubscribed" if prospect.unsubscribed?
      return "marked #{prospect.status.humanize.downcase}" if %w[customer not_interested].include?(prospect.status)
      return "an email to them is already waiting to send" if Email.where(to: prospect.email.downcase, status: "queued").exists?

      if (row = Suppression.for_email(prospect.email))
        return row.label.downcase unless @follow_up && !row.blocks_follow_ups? && row.email.present?
        return "emailed less than #{FOLLOW_UP_GAP.inspect} ago" if last_sent_recently?(prospect)
      elsif @follow_up
        return "never contacted, so there's nothing to follow up"
      end

      return if @follow_up

      colleague = colleague_contacted(prospect, also_claimed)
      "a colleague at #{prospect.organization} (#{colleague}) was already contacted" if colleague
    end

    # Another person at the same organization emailed recently (or earlier in this batch).
    # Returns that person's address, or nil.
    def colleague_contacted(prospect, also_claimed)
      domain = self.class.org_domain(prospect.email)
      key = self.class.org_key(prospect.organization)
      me = prospect.email.to_s.downcase

      claimed = also_claimed.find do |other|
        other.id != prospect.id &&
          ((domain && self.class.org_domain(other.email) == domain) || (key && self.class.org_key(other.organization) == key))
      end
      return claimed.email if claimed

      contacted = contacted_index
      [ domain && contacted[:domains][domain], key && contacted[:orgs][key] ].compact.flatten.find { |address| address != me }
    end

    private

    def last_sent_recently?(prospect)
      Email.where(to: prospect.email, status: %w[queued sent]).where(created_at: FOLLOW_UP_GAP.ago..).exists?
    end

    # Everyone emailed in the colleague window, indexed by company domain and
    # organization name. Built once per policy (i.e. once per batch).
    def contacted_index
      @contacted_index ||= begin
        index = { domains: Hash.new { |h, k| h[k] = [] }, orgs: Hash.new { |h, k| h[k] = [] } }
        Email.where(status: %w[queued sent]).where(created_at: COLLEAGUE_WINDOW.ago..)
             .joins(:prospect).pluck(:to, "outreach_prospects.organization").each do |address, organization|
          address = address.downcase
          if (domain = self.class.org_domain(address)) then index[:domains][domain] << address end
          if (key = self.class.org_key(organization)) then index[:orgs][key] << address end
        end
        index
      end
    end
  end
end
