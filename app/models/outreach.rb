# Platform-owner sales outreach: a prospect list, reusable email templates and a
# compliant sender. It only touches its own outreach_* tables plus ActionMailer,
# so it can be moved into a standalone app (see docs/OUTREACH.md).
module Outreach
  def self.table_name_prefix = "outreach_"

  # CAN-SPAM requires a valid postal address in every commercial email.
  def self.postal_address = ENV["OUTREACH_POSTAL_ADDRESS"].presence
  def self.from_address = ENV["OUTREACH_FROM"].presence || ENV["MAIL_FROM"].presence
  def self.daily_limit = ENV.fetch("OUTREACH_DAILY_LIMIT", 50).to_i

  # Token for the JSON API that AI agents use (docs/outreach-agent). Unset = API off.
  def self.api_token = ENV["OUTREACH_API_TOKEN"].presence
  # Agents can research and add prospects by default; sending stays with you
  # in the admin UI unless this is turned on.
  def self.api_can_send? = ENV["OUTREACH_API_ALLOW_SEND"] == "1"

  # Reasons sending is blocked, so the UI can explain what to configure.
  def self.configuration_problems
    problems = []
    problems << "Set OUTREACH_POSTAL_ADDRESS (a mailing address is required by CAN-SPAM)." unless postal_address
    problems << "Set OUTREACH_FROM or MAIL_FROM (the sender, e.g. \"Kyle at Swapper <kyle@yourdomain.com>\")." unless from_address
    problems
  end

  def self.sent_today
    Email.where(status: %w[queued sent]).where(created_at: Time.current.beginning_of_day..).count
  end
end
