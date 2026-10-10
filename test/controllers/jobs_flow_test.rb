require "test_helper"

class JobsFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    JobComparer.responder = ->(prompt) { prompt.scan(/^(\d+)\./).map { |(n)| { "pair" => n.to_i, "score" => 90, "reason" => "Similar." } } }
    @company = create_company
    @admin = create_user(@company)
    create_employee(@company, from: "North", to: "South", title: "RN")
    create_employee(@company, from: "South", to: "North", title: "Registered Nurse")
    sign_in_as @admin
  end

  teardown { JobComparer.responder = nil }

  test "admin turns on AI matching, reviews jobs, describes and overrides" do
    perform_enqueued_jobs do
      patch company_path, params: { company: { name: @company.name, ai_job_matching: "1" } }
    end
    assert @company.reload.ai_job_matching?
    assert_equal "similar_job", Match.sole.match_type

    get jobs_path
    assert_response :success
    assert_match "Registered Nurse", response.body

    patch describe_jobs_path, params: { title: "RN", description: "Bedside nursing" }
    assert_equal "Bedside nursing", @company.job_profiles.find_by!(title_key: "rn").description

    row = JobSimilarity.sole
    patch override_job_similarity_path(row, similar: "0")
    assert row.reload.manual?
    assert_equal 0, Match.count, "overriding to not-similar removes the pending match"

    patch recheck_job_similarity_path(row)
    assert_equal "ai", row.reload.source
  end

  test "managers can't reach the jobs page" do
    sign_in_as create_user(@company, role: "manager")
    get jobs_path
    assert_redirected_to dashboard_path
  end
end
