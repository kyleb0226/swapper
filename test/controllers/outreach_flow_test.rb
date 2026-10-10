require "test_helper"

class OutreachFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ENV["OUTREACH_POSTAL_ADDRESS"] = "123 Main St"
    ENV["OUTREACH_FROM"] = "kyle@example.com"
    @owner = User.create!(email: "owner@example.com", password: TestData::PASSWORD, platform_admin: true, activated_at: Time.current)
    @template = Outreach::EmailTemplate.create!(name: "Intro", subject: "Hi {{organization}}", body: "Hello {{first_name}}")
    @prospect = Outreach::Prospect.create!(organization: "County HR", contact_name: "Sam", email: "sam@county.gov")
  end

  teardown do
    ENV.delete("OUTREACH_POSTAL_ADDRESS")
    ENV.delete("OUTREACH_FROM")
  end

  test "owner previews then sends a campaign" do
    sign_in_as @owner
    post preview_admin_outreach_campaigns_path, params: { template_id: @template.id, prospect_ids: [ @prospect.id ] }
    assert_response :success
    assert_match "Hi County HR", response.body

    assert_enqueued_jobs 1, only: Outreach::DeliveryJob do
      post admin_outreach_campaigns_path, params: { template_id: @template.id, prospect_ids: [ @prospect.id ] }
    end
    assert_redirected_to admin_outreach_emails_path
    get admin_outreach_prospect_path(@prospect)
    assert_response :success
  end

  test "anyone with the link can unsubscribe, including one-click POST" do
    token = @prospect.generate_token_for(:unsubscribe)
    get outreach_unsubscribe_path(token)
    assert_response :success
    post outreach_unsubscribe_path(token)
    assert_response :success
    assert @prospect.reload.unsubscribed?
  end

  test "owner manages the do-not-contact list; unsubscribes can't be removed" do
    sign_in_as @owner
    post admin_outreach_suppressions_path, params: { outreach_suppression: { value: "https://www.Customer.com/about", reason: "customer" } }
    assert Outreach::Suppression.exists?(domain: "customer.com", reason: "customer")
    get admin_outreach_suppressions_path
    assert_response :success

    unsub = Outreach::Suppression.create!(email: "gone@x.gov", reason: "unsubscribed")
    delete admin_outreach_suppression_path(unsub)
    assert Outreach::Suppression.exists?(unsub.id)

    post outreach_unsubscribe_path(@prospect.generate_token_for(:unsubscribe))
    assert_equal "unsubscribed", Outreach::Suppression.find_by!(email: "sam@county.gov").reason
  end

  test "preview lists who will be skipped and why" do
    Outreach::Suppression.record!("sam@county.gov", "contacted")
    other = Outreach::Prospect.create!(organization: "State DOT", email: "hr@dot.gov")
    sign_in_as @owner
    post preview_admin_outreach_campaigns_path, params: { template_id: @template.id, prospect_ids: [ @prospect.id, other.id ] }
    assert_response :success
    assert_match "1 prospect will be skipped", response.body
    assert_match "already contacted", response.body
  end

  test "owner can create and import prospects" do
    sign_in_as @owner
    post admin_outreach_prospects_path, params: { outreach_prospect: { organization: "State DOT", email: "hr@dot.gov", status: "new" } }
    assert_redirected_to admin_outreach_prospect_path(Outreach::Prospect.find_by!(email: "hr@dot.gov"))

    csv = "Company,Email\nCity Library,lib@city.gov\n"
    post import_admin_outreach_prospects_path, params: { file: Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: "p.csv") }
    assert_response :success
    assert Outreach::Prospect.exists?(email: "lib@city.gov")
  end
end
