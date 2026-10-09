require "test_helper"

class AccountsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "sign up creates a new company with the person as HR admin" do
    post sign_up_path, params: { user: { company_name: "Metro Transit", name: "Pat", email: "Pat@Metro.gov",
                                         password: "longpassword", password_confirmation: "longpassword" } }
    assert_redirected_to dashboard_path
    user = User.find_by!(email: "pat@metro.gov")
    assert_equal "admin", user.role
    assert_equal "Metro Transit", user.company.name
  end

  test "signing up with an existing company's name does not grant access to it" do
    existing = create_company("Metro Transit")
    post sign_up_path, params: { user: { company_name: "Metro Transit", email: "intruder@example.com",
                                         password: "longpassword", password_confirmation: "longpassword" } }
    assert_not_equal existing, User.find_by!(email: "intruder@example.com").company
  end

  test "sign up shows errors for bad input" do
    post sign_up_path, params: { user: { company_name: "", email: "bad", password: "short", password_confirmation: "short" } }
    assert_response :unprocessable_entity
    assert_equal 0, Company.count
  end

  test "sign in with a wrong password fails" do
    user = create_user(create_company)
    post sign_in_path, params: { email: user.email, password: "wrong" }
    assert_response :unprocessable_entity
  end

  test "invited staff activate their account through the emailed link" do
    company = create_company
    admin = create_user(company)
    sign_in_as admin
    employee = create_employee(company, from: "North", email: "worker@example.com")

    assert_enqueued_emails 1 do
      post team_members_path, params: { user: { email: "worker@example.com", name: "Wendy", role: "employee" } }
    end
    invited = User.find_by!(email: "worker@example.com")
    assert invited.pending_invitation?
    assert_equal invited, employee.reload.user

    delete logout_path
    token = invited.generate_token_for(:invitation)
    patch invitation_path(token), params: { user: { name: "Wendy", password: "newpassword1", password_confirmation: "newpassword1" } }
    assert_redirected_to my_request_path
    assert_not invited.reload.pending_invitation?

    get edit_invitation_path(token)
    assert_redirected_to sign_in_path, "invitation links are single use"
  end

  test "password reset works once with a valid token" do
    user = create_user(create_company)
    assert_enqueued_emails 1 do
      post password_resets_path, params: { email: user.email }
    end
    token = user.generate_token_for(:password_reset)
    patch password_reset_path(token), params: { user: { password: "brandnewpass", password_confirmation: "brandnewpass" } }
    assert_redirected_to sign_in_path
    assert user.reload.authenticate("brandnewpass")

    get edit_password_reset_path(token)
    assert_redirected_to new_password_reset_path
  end

  test "changing password requires the current password" do
    user = create_user(create_company)
    sign_in_as user
    patch password_path, params: { user: { current_password: "nope", password: "anotherpass1", password_confirmation: "anotherpass1" } }
    assert_response :unprocessable_entity
    patch password_path, params: { user: { current_password: TestData::PASSWORD, password: "anotherpass1", password_confirmation: "anotherpass1" } }
    assert_redirected_to edit_password_path
    assert user.reload.authenticate("anotherpass1")
  end
end
