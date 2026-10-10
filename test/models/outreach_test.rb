require "test_helper"

class OutreachTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ENV["OUTREACH_POSTAL_ADDRESS"] = "123 Main St, Columbus, OH 43215"
    ENV["OUTREACH_FROM"] = "Kyle <kyle@example.com>"
    @template = Outreach::EmailTemplate.create!(name: "Intro", subject: "Hi {{organization}}", body: "Hello {{first_name}} at {{organization}}.")
    @prospect = Outreach::Prospect.create!(organization: "Ohio DOC", contact_name: "Dana Smith", email: "dana@ohio.gov")
  end

  teardown do
    ENV.delete("OUTREACH_POSTAL_ADDRESS")
    ENV.delete("OUTREACH_FROM")
    ENV.delete("OUTREACH_DAILY_LIMIT")
  end

  test "templates fill merge tags" do
    assert_equal({ subject: "Hi Ohio DOC", body: "Hello Dana at Ohio DOC." }, @template.render_for(@prospect))
  end

  test "sent email includes postal address, unsubscribe link and list-unsubscribe header" do
    email = @prospect.emails.create!(to: @prospect.email, **@template.render_for(@prospect))
    Outreach::DeliveryJob.perform_now(email)

    assert_equal "sent", email.reload.status
    assert_equal "contacted", @prospect.reload.status
    message = ActionMailer::Base.deliveries.last
    assert_equal [ "kyle@example.com" ], message.from
    assert_match "123 Main St", message.text_part.body.to_s
    assert_match "/unsubscribe/", message.text_part.body.to_s
    assert message["List-Unsubscribe"].present?
  end

  test "campaign skips unsubscribed prospects and respects the daily limit" do
    ENV["OUTREACH_DAILY_LIMIT"] = "1"
    unsubscribed = Outreach::Prospect.create!(organization: "Gone", email: "gone@example.com", unsubscribed_at: Time.current)
    third = Outreach::Prospect.create!(organization: "Third", email: "third@example.com")

    result = Outreach::Campaign.new(template: @template, prospects: [ unsubscribed, @prospect, third ]).send!

    assert_equal 1, result.queued
    assert_equal 1, result.skipped
    assert_match "Daily limit", result.errors.join
    assert_enqueued_jobs 1, only: Outreach::DeliveryJob
  end

  test "campaign refuses to send without a postal address" do
    ENV.delete("OUTREACH_POSTAL_ADDRESS")
    result = Outreach::Campaign.new(template: @template, prospects: [ @prospect ]).send!
    assert_equal 0, result.queued
    assert_match "OUTREACH_POSTAL_ADDRESS", result.errors.join
  end

  test "delivery skips prospects who unsubscribed after queueing" do
    email = @prospect.emails.create!(to: @prospect.email, **@template.render_for(@prospect))
    @prospect.update!(unsubscribed_at: Time.current)
    Outreach::DeliveryJob.perform_now(email)
    assert_equal "skipped", email.reload.status
  end

  test "importer understands common export column names" do
    csv = <<~CSV
      Company Name,First Name,Last Name,Title,Email,Industry,State
      Metro Schools,Lee,Park,HR Director,LEE@metro.k12.us,Public school district,TX
      Metro Schools,,,,lee@metro.k12.us,,
    CSV
    result = Outreach::ProspectImporter.new.import(csv, source: "Apollo")

    assert_equal 2, result.imported
    prospect = Outreach::Prospect.find_by!(email: "lee@metro.k12.us")
    assert_equal "Lee Park", prospect.contact_name
    assert_equal "HR Director", prospect.contact_title
    assert_equal "Apollo", prospect.source
  end

  test "lead source searches build URLs for a sector and region" do
    searches = Outreach::LeadSources.searches(sector: "Public school district", region: "Ohio")
    assert searches.all? { |_label, url| url.start_with?("https://") }
    assert_match "Ohio", CGI.unescape(searches.first.last)
  end
end
