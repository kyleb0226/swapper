require "test_helper"

class OutreachContactPolicyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ENV["OUTREACH_POSTAL_ADDRESS"] = "123 Main St"
    ENV["OUTREACH_FROM"] = "kyle@example.com"
    @template = Outreach::EmailTemplate.create!(name: "Intro", subject: "Hi", body: "Hello {{first_name}}")
  end

  teardown do
    ENV.delete("OUTREACH_POSTAL_ADDRESS")
    ENV.delete("OUTREACH_FROM")
  end

  def prospect(email, organization = "Org #{SecureRandom.hex(2)}")
    Outreach::Prospect.create!(organization: organization, email: email, contact_name: "Pat")
  end

  def send_to(*prospects, follow_up: false)
    result = Outreach::Campaign.new(template: @template, prospects: prospects, follow_up: follow_up).send!
    perform_enqueued_jobs
    result
  end

  test "someone emailed once is never emailed automatically again, even months later" do
    dana = prospect("dana@ohio.gov", "Ohio DOC")
    assert_equal 1, send_to(dana).queued
    assert_equal "contacted", Outreach::Suppression.find_by!(email: "dana@ohio.gov").reason

    travel 120.days do
      result = send_to(dana)
      assert_equal 0, result.queued
      assert_equal "already contacted", result.skipped_reasons["Ohio DOC"]
    end
  end

  test "the block survives deleting and re-adding the prospect" do
    send_to(prospect("dana@ohio.gov", "Ohio DOC"))
    Outreach::Prospect.find_by!(email: "dana@ohio.gov").destroy
    readded = prospect("Dana@Ohio.gov", "Ohio DOC")
    assert_equal "already contacted", readded.contact_blocked_reason
  end

  test "only one person per organization, by company email domain or by name" do
    first = prospect("hr@metro.k12.us", "Metro Schools")
    colleague = prospect("super@metro.k12.us", "Metro Public Schools")
    same_name = prospect("someone@othermail.org", "Metro Schools")

    result = send_to(first, colleague, same_name)
    assert_equal 1, result.queued, "colleagues in the same batch are skipped"
    assert_match "colleague", result.skipped_reasons["Metro Public Schools"]

    assert_match "colleague", colleague.reload.contact_blocked_reason
  end

  test "people at different companies who share a personal email provider are not grouped" do
    a = prospect("a@gmail.com", "Clinic A")
    b = prospect("b@gmail.com", "Clinic B")
    assert_equal 2, send_to(a, b).queued
  end

  test "follow-ups only go to people already contacted, at least 3 days later" do
    dana = prospect("dana@ohio.gov")
    fresh = prospect("new@county.gov")
    send_to(dana)

    assert_equal 0, send_to(dana, follow_up: true).queued, "too soon"
    travel 4.days do
      result = send_to(dana, fresh, follow_up: true)
      assert_equal 1, result.queued
      assert_equal "sent", Outreach::Email.where(to: "dana@ohio.gov").order(:created_at).last.status
    end
  end

  test "if the same person was queued twice, only the first one sends" do
    dana = prospect("dana@ohio.gov")
    first = dana.emails.create!(to: dana.email, subject: "a", body: "b")
    second = dana.emails.create!(to: dana.email, subject: "a", body: "b")
    Outreach::DeliveryJob.perform_now(first)
    Outreach::DeliveryJob.perform_now(second)
    assert_equal %w[sent skipped], [ first.reload.status, second.reload.status ]
    assert_equal 1, ActionMailer::Base.deliveries.count { |m| m.to == [ "dana@ohio.gov" ] }
  end

  test "bounced and blocked-domain addresses are never emailed" do
    bad = prospect("nobody@county.gov")
    email = bad.emails.create!(to: bad.email, subject: "a", body: "b")
    Outreach::ProspectMailer.define_singleton_method(:with) { |*| raise Net::SMTPFatalError, "550 5.1.1 User unknown" }
    begin
      Outreach::DeliveryJob.perform_now(email)
    ensure
      Outreach::ProspectMailer.singleton_class.remove_method(:with)
    end
    assert_equal "failed", email.reload.status
    assert_equal "bounced", Outreach::Suppression.find_by!(email: "nobody@county.gov").reason

    Outreach::Suppression.create!(domain: "bigcustomer.com", reason: "customer")
    assert_equal "existing customer", prospect("ceo@bigcustomer.com").contact_blocked_reason
  end

  test "unsubscribe goes on the list and stays stronger than contacted" do
    dana = prospect("dana@ohio.gov")
    Outreach::Suppression.record!("dana@ohio.gov", "unsubscribed")
    Outreach::Suppression.record!("dana@ohio.gov", "contacted")
    assert_equal "unsubscribed", Outreach::Suppression.find_by!(email: "dana@ohio.gov").reason
    assert_equal 0, send_to(dana, follow_up: true).queued
  end
end
