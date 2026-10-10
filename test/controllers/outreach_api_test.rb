require "test_helper"

class OutreachApiTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  TOKEN = "test-token-123"

  setup do
    ENV["OUTREACH_API_TOKEN"] = TOKEN
    ENV["OUTREACH_POSTAL_ADDRESS"] = "123 Main St"
    ENV["OUTREACH_FROM"] = "kyle@example.com"
    @template = Outreach::EmailTemplate.create!(name: "Intro", subject: "Hi {{organization}}", body: "Hello {{first_name}}")
  end

  teardown do
    %w[OUTREACH_API_TOKEN OUTREACH_API_ALLOW_SEND OUTREACH_POSTAL_ADDRESS OUTREACH_FROM].each { |key| ENV.delete(key) }
  end

  def auth(token = TOKEN) = { "Authorization" => "Bearer #{token}" }

  test "requires the right token, and is off when no token is configured" do
    get api_outreach_status_path, headers: auth("wrong")
    assert_response :unauthorized

    ENV.delete("OUTREACH_API_TOKEN")
    get api_outreach_status_path, headers: auth
    assert_response :service_unavailable
  end

  test "status reports sending is off by default" do
    get api_outreach_status_path, headers: auth
    assert_response :success
    assert_equal false, response.parsed_body["can_send"]
    assert_equal 50, response.parsed_body["remaining_today"]
  end

  test "agent adds a prospect, and re-adding the same email updates instead of duplicating" do
    post api_outreach_prospects_path, headers: auth, as: :json,
         params: { prospect: { organization: "Ohio DOC", contact_name: "Dana", email: "Dana@ohio.gov", sector: "Corrections / public safety" } }
    assert_response :created
    assert_equal "AI agent", response.parsed_body["source"]

    Outreach::Prospect.find_by!(email: "dana@ohio.gov").update!(status: "not_interested")
    post api_outreach_prospects_path, headers: auth, as: :json,
         params: { prospect: { organization: "Ohio DOC", email: "dana@ohio.gov", notes: "Found on LinkedIn", status: "new" } }
    assert_response :ok
    assert_equal 1, Outreach::Prospect.count
    prospect = Outreach::Prospect.sole
    assert_equal "not_interested", prospect.status, "agents can't reset a prospect who declined"
    assert_equal "Found on LinkedIn", prospect.notes
  end

  test "lists prospects, templates, emails and lead sources" do
    Outreach::Prospect.create!(organization: "Metro Schools", state: "TX")
    get api_outreach_prospects_path(state: "TX"), headers: auth
    assert_equal [ "Metro Schools" ], response.parsed_body["prospects"].map { |p| p["organization"] }

    get api_outreach_templates_path, headers: auth
    assert_equal [ "Intro" ], response.parsed_body["templates"].map { |t| t["name"] }

    get api_outreach_emails_path, headers: auth
    assert_response :success

    get api_outreach_lead_sources_path(sector: "Healthcare system", region: "Ohio"), headers: auth
    assert response.parsed_body["sources"].any?
    assert_equal 5, response.parsed_body["searches"].size
  end

  test "sending is refused unless enabled, then never repeats a recent email" do
    prospect = Outreach::Prospect.create!(organization: "County HR", contact_name: "Sam", email: "sam@county.gov")
    post api_outreach_campaigns_path, headers: auth, as: :json, params: { template_id: @template.id, prospect_ids: [ prospect.id ] }
    assert_response :forbidden

    ENV["OUTREACH_API_ALLOW_SEND"] = "1"
    post api_outreach_campaigns_path, headers: auth, as: :json, params: { template_id: @template.id, prospect_ids: [ prospect.id ] }
    assert_response :success
    assert_equal 1, response.parsed_body["queued"]

    post api_outreach_campaigns_path, headers: auth, as: :json, params: { template_id: @template.id, prospect_ids: [ prospect.id ] }
    assert_equal 0, response.parsed_body["queued"]
    assert_equal 1, response.parsed_body["skipped"]
    assert_equal 1, Outreach::Email.count
  end
end

class OutreachApiCheckTest < ActionDispatch::IntegrationTest
  setup { ENV["OUTREACH_API_TOKEN"] = "t" }
  teardown { ENV.delete("OUTREACH_API_TOKEN") }

  def auth = { "Authorization" => "Bearer t" }

  test "check says whether a person or organization may be contacted" do
    get api_outreach_check_path(email: "new@county.gov", organization: "Example County"), headers: auth
    assert response.parsed_body["can_contact"]

    prospect = Outreach::Prospect.create!(organization: "Example County", email: "hr@county.gov")
    Outreach::Suppression.record!("hr@county.gov", "contacted")
    prospect.emails.create!(to: "hr@county.gov", subject: "a", body: "b", status: "sent")

    get api_outreach_check_path(email: "hr@county.gov"), headers: auth
    assert_equal false, response.parsed_body["can_contact"]
    assert_equal "already contacted", response.parsed_body["reason"]

    get api_outreach_check_path(email: "director@county.gov", organization: "Example County"), headers: auth
    assert_equal false, response.parsed_body["can_contact"]
    assert_match "colleague", response.parsed_body["reason"]

    get api_outreach_check_path(organization: "Example County"), headers: auth
    assert_equal false, response.parsed_body["can_contact"]
    assert_equal [ "hr@county.gov" ], response.parsed_body["organization_contacts"].map { |p| p["email"] }
  end

  test "prospects report whether they can be emailed" do
    Outreach::Prospect.create!(organization: "A", email: "a@a.gov")
    Outreach::Suppression.record!("a@a.gov", "contacted")
    get api_outreach_prospects_path, headers: auth
    row = response.parsed_body["prospects"].first
    assert_equal false, row["can_email"]
    assert_equal "already contacted", row["blocked_reason"]
  end
end
