require "test_helper"

class SwapMatcherTest < ActiveSupport::TestCase
  setup do
    @company = create_company
    @matcher = SwapMatcher.new(@company)
  end

  test "matches two employees who want each other's location with the same job code" do
    a = create_employee(@company, from: "North", to: "South")
    b = create_employee(@company, from: "South", to: "North")

    created = @matcher.refresh(b)

    assert_equal 1, created.size
    match = created.first
    assert_equal "job_code", match.match_type
    assert_equal "pending", match.status
    assert_equal [ a, b ].sort_by(&:id), match.employees
  end

  test "labels same title with different codes as a job title match, case-insensitively" do
    create_employee(@company, from: "North", to: "South", title: "Nurse", code: "RN1")
    b = create_employee(@company, from: "South", to: "North", title: "NURSE", code: "RN2")

    assert_equal "job_title", @matcher.refresh(b).first.match_type
  end

  test "does not match different jobs, one-way requests, or other companies" do
    create_employee(@company, from: "North", to: "South", title: "Teacher")
    create_employee(@company, from: "South", to: "East")
    other = create_company
    create_employee(other, from: "North", to: "South")
    b = create_employee(@company, from: "South", to: "North")

    assert_empty @matcher.refresh(b)
  end

  test "does not create duplicates when run repeatedly" do
    create_employee(@company, from: "North", to: "South")
    create_employee(@company, from: "South", to: "North")

    assert_equal 1, @matcher.refresh_all
    assert_equal 0, @matcher.refresh_all
    assert_equal 1, Match.count
  end

  test "never re-proposes a rejected pair" do
    create_employee(@company, from: "North", to: "South")
    create_employee(@company, from: "South", to: "North")
    @matcher.refresh_all
    Match.first.update!(status: "rejected")

    assert_equal 0, @matcher.refresh_all
    assert_equal [ "rejected" ], Match.pluck(:status)
  end

  test "removes a pending match when an employee changes their request" do
    a = create_employee(@company, from: "North", to: "South")
    create_employee(@company, from: "South", to: "North")
    @matcher.refresh_all

    a.update!(desired_location: location(@company, "East"))
    @matcher.refresh(a)

    assert_equal 0, Match.count
  end

  test "employees locked into an approved swap are not offered new matches" do
    a = create_employee(@company, from: "North", to: "South")
    create_employee(@company, from: "South", to: "North")
    @matcher.refresh_all
    Match.first.update!(status: "approved")

    c = create_employee(@company, from: "South", to: "North")
    assert_empty @matcher.refresh(c)
    assert_not a.reload.all_matches.pending.exists?
  end
end
