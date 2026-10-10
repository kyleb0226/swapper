require "test_helper"

class SwapFlowTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin = create_user(@company)
    @worker = create_user(@company, role: "employee")
    @employee = create_employee(@company, from: "North", user: @worker)
  end

  test "worker request creates a match that HR approves and completes" do
    partner = create_employee(@company, from: "South", to: "North")

    sign_in_as @worker
    patch my_request_path, params: { employee: { desired_location_id: location(@company, "South").id, request_note: "closer to home" } }
    assert_redirected_to my_request_path
    match = Match.sole
    follow_redirect!
    assert_match "Match found", response.body

    sign_in_as @admin
    get matches_path
    assert_match partner.name, response.body
    patch approve_match_path(match)
    patch complete_match_path(match)
    assert match.reload.completed?
    assert_equal "South", @employee.reload.current_location.name
  end

  test "workers can't change an approved request" do
    create_employee(@company, from: "South", to: "North")
    @employee.update!(desired_location: location(@company, "South"))
    SwapMatcher.new(@company).refresh_all
    Match.sole.update!(status: "approved")

    sign_in_as @worker
    patch my_request_path, params: { employee: { desired_location_id: "" } }
    assert_equal "South", @employee.reload.desired_location.name
  end

  test "employee CSV import creates employees, locations and matches" do
    csv = <<~CSV
      name,email,job_title,job_code,seniority,current_location,desired_location
      Ann,ann@example.com,Teacher,T1,4,Lincoln Elementary,Roosevelt Elementary
      Ben,ben@example.com,Teacher,T1,9,Roosevelt Elementary,Lincoln Elementary
      Bad Row,,,,,,
    CSV
    sign_in_as @admin
    post import_employees_path, params: { file: Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: "e.csv") }
    assert_response :success
    assert_match "Imported 2 employees", response.body
    assert_match "Row 4", response.body
    assert @company.locations.exists?(name: "Lincoln Elementary")
    assert_equal 1, @company.matches.pending.count
  end
end
