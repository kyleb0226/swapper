require "test_helper"

class MatchRulesTest < ActiveSupport::TestCase
  # A bespoke rule like the ones built for individual customers.
  class MatchRules::Custom::SameUnionLocalForTest < MatchRules::Custom::Base
    NAME = "Same union local"
    def allows?(a, b) = a.custom_field("union_local") == b.custom_field("union_local")
  end

  setup do
    @company = create_company
  end

  # Each pair gets its own job title so pairs never match each other.
  def pair(a_attrs = {}, b_attrs = {})
    title = "Job #{SecureRandom.hex(3)}"
    a = create_employee(@company, from: "North", to: "South", title: title, **a_attrs)
    b = create_employee(@company, from: "South", to: "North", title: title, **b_attrs)
    [ a, b ]
  end

  def matches_after_refresh
    SwapMatcher.new(@company.reload).refresh_all
  end

  test "no rules keeps standard matching" do
    pair
    assert_equal 1, matches_after_refresh
    assert_empty @company.rules.describe
  end

  test "minimum seniority blocks juniors" do
    @company.update!(match_rules: { min_seniority: "3" })
    pair({ seniority: 2 }, { seniority: 10 })
    assert_equal 0, matches_after_refresh

    pair({ seniority: 3 }, { seniority: 4 })
    assert_equal 1, matches_after_refresh
  end

  test "maximum seniority gap" do
    @company.update!(match_rules: { max_seniority_gap: 2 })
    pair({ seniority: 1 }, { seniority: 9 })
    assert_equal 0, matches_after_refresh
  end

  test "same job code only rejects same title with different codes" do
    @company.update!(match_rules: { same_job_code_only: "1" })
    pair({ code: "RN1" }, { code: "RN2" })
    assert_equal 0, matches_after_refresh
  end

  test "same custom fields must be present and equal, case-insensitively" do
    @company.update!(match_rules: { same_fields: "Shift, department" })
    assert_equal %w[shift department], @company.rules.same_fields

    pair({ custom_fields: { "shift" => "Night", "department" => "ICU" } }, { custom_fields: { "Shift" => "night", "department" => "icu" } })
    assert_equal 1, matches_after_refresh

    pair({ custom_fields: { "shift" => "Night", "department" => "ICU" } }, { custom_fields: { "shift" => "Day", "department" => "ICU" } })
    pair({ custom_fields: { "shift" => "Night" } }, { custom_fields: { "shift" => "Night" } }) # department missing
    assert_equal 0, matches_after_refresh
  end

  test "a customer's custom rule applies only to that company" do
    @company.update!(custom_rule: "same_union_local_for_test")
    other = create_company
    pair({ custom_fields: { union_local: "100" } }, { custom_fields: { union_local: "200" } })
    create_employee(other, from: "North", to: "South", custom_fields: { union_local: "100" })
    create_employee(other, from: "South", to: "North", custom_fields: { union_local: "200" })

    assert_equal 0, matches_after_refresh
    assert_equal 1, SwapMatcher.new(other).refresh_all
    assert_includes @company.rules.describe, "Same union local (custom)"
  end

  test "rejects unknown custom rule keys" do
    @company.custom_rule = "does_not_exist"
    assert_not @company.valid?
  end

  test "tightening rules drops pending suggestions but keeps approved swaps" do
    a, b = pair({ seniority: 1 }, { seniority: 1 })
    c, d = pair({ seniority: 1 }, { seniority: 1 })
    matches_after_refresh
    Match.find_by(employee: [ c, d ].min_by(&:id)).update!(status: "approved")

    @company.update!(match_rules: { min_seniority: 5 })
    matches_after_refresh

    assert_equal [ "approved" ], Match.where(company: @company).pluck(:status)
  end

  test "CSV import keeps extra columns as custom fields" do
    csv = "name,email,job_title,current_location,Shift,Union Local\nAva,ava@x.com,Nurse,North,Night,42\n"
    result = EmployeeImporter.new(@company).import(csv)
    assert_empty result.errors
    assert_equal({ "shift" => "Night", "union_local" => "42" }, @company.employees.last.custom_fields)
  end

  test "clean drops blanks and normalises field names" do
    assert_equal({ "same_fields" => %w[night_shift] }, MatchRules.clean(min_seniority: "", same_job_code_only: "0", same_fields: " Night Shift ,, "))
  end
end
