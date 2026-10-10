require "test_helper"

class CustomRequestsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  VALID = { name: "Dana Lee", email: "Dana@Metro.gov", organization: "Metro Transit", employee_count: "500–2,000",
            message: "Operators can only swap within the same union local." }.freeze

  test "home page and custom page show the offer" do
    get root_path
    assert_select "#custom form[action=?]", custom_requests_path
    get custom_path
    assert_response :success
    assert_select "h2", /Need it to work your way/
  end

  test "a visitor can send a request and the owner is emailed" do
    assert_enqueued_emails 1 do
      post custom_requests_path, params: { custom_request: VALID }
    end
    assert_redirected_to custom_path(sent: 1)
    request = CustomRequest.last
    assert_equal "dana@metro.gov", request.email
    assert_equal "new", request.status
  end

  test "invalid requests re-render with errors" do
    post custom_requests_path, params: { custom_request: VALID.merge(email: "nope", message: "") }
    assert_response :unprocessable_entity
    assert_equal 0, CustomRequest.count
  end

  test "bots filling the hidden field are ignored" do
    post custom_requests_path, params: { website: "http://spam", custom_request: VALID }
    assert_redirected_to custom_path(sent: 1)
    assert_equal 0, CustomRequest.count
  end

  test "only the platform owner sees and works requests" do
    request = CustomRequest.create!(VALID)
    company = create_company
    sign_in_as create_user(company, role: "admin")
    get admin_custom_requests_path
    assert_redirected_to dashboard_path

    owner = User.create!(email: "owner@example.com", password: TestData::PASSWORD, platform_admin: true, activated_at: Time.current)
    sign_in_as owner
    get admin_custom_requests_path
    assert_select "td", /Metro Transit/
    get admin_root_path
    assert_select ".card-header", /Custom requests/
    patch admin_custom_request_path(request), params: { custom_request: { status: "quoted", notes: "$500 setup" } }
    assert_equal "quoted", request.reload.status
  end
end
