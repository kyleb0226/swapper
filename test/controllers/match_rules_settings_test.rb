require "test_helper"

class MatchRulesSettingsTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin = create_user(@company, role: "admin")
  end

  test "HR admin sets rules and matching re-runs" do
    create_employee(@company, from: "North", to: "South", seniority: 1)
    create_employee(@company, from: "South", to: "North", seniority: 1)
    SwapMatcher.new(@company).refresh_all
    assert_equal 1, @company.matches.count

    sign_in_as @admin
    get edit_company_path
    assert_select "input[name=?]", "company[match_rules][same_fields]"
    patch company_path, params: { company: { name: @company.name, match_rules: { min_seniority: "2", same_fields: "shift" } } }
    assert_redirected_to edit_company_path

    assert_equal({ "min_seniority" => 2, "same_fields" => [ "shift" ] }, @company.reload.match_rules)
    assert_equal 0, @company.matches.count
  end

  test "employee form shows rule fields and saves them" do
    @company.update!(match_rules: { same_fields: "shift" })
    employee = create_employee(@company, from: "North")
    sign_in_as @admin
    get edit_employee_path(employee)
    assert_select "input[name=?]", "employee[custom_fields][shift]"
    patch employee_path(employee), params: { employee: { custom_fields: { shift: " Night " } } }
    assert_equal "Night", employee.reload.custom_field("shift")
  end

  test "managers cannot change matching rules" do
    sign_in_as create_user(@company, role: "manager")
    patch company_path, params: { company: { match_rules: { min_seniority: "9" } } }
    assert_empty @company.reload.match_rules
  end

  test "owner can view a customer's rules" do
    owner = User.create!(email: "owner2@example.com", password: TestData::PASSWORD, platform_admin: true, activated_at: Time.current)
    @company.update!(match_rules: { same_job_code_only: true })
    sign_in_as owner
    get admin_company_path(@company)
    assert_select "li", "Same job code only"
  end
end
