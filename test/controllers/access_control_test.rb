require "test_helper"

class AccessControlTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin = create_user(@company, role: "admin")
    @manager = create_user(@company, role: "manager")
    @worker = create_user(@company, role: "employee")
    @employee = create_employee(@company, from: "North", to: "South", user: @worker)
    create_employee(@company, from: "South", to: "North")
    SwapMatcher.new(@company).refresh_all
    @match = Match.first

    @other_company = create_company
    @outsider = create_user(@other_company, role: "admin")
  end

  test "signed-out visitors are sent to sign in" do
    [ dashboard_path, employees_path, matches_path, locations_path, my_request_path, admin_root_path ].each do |path|
      get path
      assert_redirected_to sign_in_path, "expected #{path} to require sign in"
    end
  end

  test "workers can only reach their own request page" do
    sign_in_as @worker
    get my_request_path
    assert_response :success

    [ dashboard_path, employees_path, matches_path, employee_path(@employee), locations_path, team_members_path, admin_root_path ].each do |path|
      get path
      assert_response :redirect, "expected worker to be blocked from #{path}"
    end
    patch approve_match_path(@match)
    assert @match.reload.pending?
  end

  test "managers manage employees and matches but not settings" do
    sign_in_as @manager
    [ dashboard_path, employees_path, matches_path, employee_path(@employee), match_path(@match) ].each do |path|
      get path
      assert_response :success, "expected manager to reach #{path}"
    end
    [ locations_path, team_members_path, activity_path, edit_company_path ].each do |path|
      get path
      assert_redirected_to dashboard_path, "expected manager to be blocked from #{path}"
    end
  end

  test "HR admins can reach every company page" do
    sign_in_as @admin
    [ dashboard_path, employees_path, new_employee_path, import_employees_path, matches_path, locations_path,
      new_location_path, team_members_path, new_team_member_path, activity_path, edit_company_path, edit_password_path ].each do |path|
      get path
      assert_response :success, "expected admin to reach #{path}"
    end
  end

  test "users can never see or change another company's records" do
    sign_in_as @outsider
    get employee_path(@employee)
    assert_response :not_found
    get match_path(@match)
    assert_response :not_found
    patch approve_match_path(@match)
    assert_response :not_found
    assert @match.reload.pending?

    get employees_path
    assert_no_match @employee.name, response.body
  end

  test "employee form rejects another company's locations" do
    sign_in_as @outsider
    post employees_path, params: { employee: { name: "X", job_title: "Nurse", seniority: 1,
                                               current_location_id: location(@other_company, "North").id,
                                               desired_location_id: location(@company, "South").id } }
    assert_response :unprocessable_entity
  end

  test "only platform admins reach the owner area" do
    sign_in_as @admin
    get admin_root_path
    assert_redirected_to dashboard_path

    owner = User.create!(email: "owner@example.com", password: TestData::PASSWORD, platform_admin: true, activated_at: Time.current)
    sign_in_as owner
    [ admin_root_path, admin_companies_path, admin_company_path(@company), admin_outreach_lead_sources_path,
      admin_outreach_lead_sources_path(sector: "Public school district", region: "Ohio"), admin_outreach_prospects_path,
      new_admin_outreach_prospect_path, import_admin_outreach_prospects_path, admin_outreach_templates_path,
      new_admin_outreach_template_path, new_admin_outreach_campaign_path, admin_outreach_emails_path ].each do |path|
      get path
      assert_response :success, "expected owner to reach #{path}"
    end
  end

  test "admins cannot demote or remove themselves" do
    sign_in_as @admin
    patch team_member_path(@admin), params: { user: { role: "employee" } }
    assert_equal "admin", @admin.reload.role
    delete team_member_path(@admin)
    assert User.exists?(@admin.id)
  end
end
