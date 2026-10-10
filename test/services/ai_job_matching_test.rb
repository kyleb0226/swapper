require "test_helper"

class AiJobMatchingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @company = create_company
    @company.update!(ai_job_matching: true)
    @calls = []
    # Fake AI: "RN" and "Registered Nurse" are the same job; anything else isn't.
    JobComparer.responder = lambda do |prompt|
      @calls << prompt
      prompt.scan(/^(\d+)\. "([^"]+)".*\n\s+vs "([^"]+)"/).map do |n, a, b|
        same = [ a, b ].map(&:downcase).sort == [ "registered nurse", "rn" ]
        { "pair" => n.to_i, "score" => same ? 95 : 20, "reason" => same ? "Same role, abbreviated." : "Different work." }
      end
    end
  end

  teardown { JobComparer.responder = nil }

  def nurse_pair
    a = create_employee(@company, from: "North", to: "South", title: "RN", code: nil)
    b = create_employee(@company, from: "South", to: "North", title: "Registered Nurse", code: nil)
    [ a, b ]
  end

  test "different but similar jobs are compared once by AI and then matched" do
    nurse_pair
    perform_enqueued_jobs { SwapMatcher.new(@company).refresh_all }

    match = Match.sole
    assert_equal "similar_job", match.match_type
    assert_equal "Same role, abbreviated.", match.similarity.reason
    assert_equal 1, @calls.size

    perform_enqueued_jobs { SwapMatcher.new(@company).refresh_all }
    assert_equal 1, @calls.size, "an already compared pair is never sent to the AI again"
  end

  test "jobs the AI says are different don't match" do
    create_employee(@company, from: "North", to: "South", title: "RN")
    create_employee(@company, from: "South", to: "North", title: "Janitor")
    perform_enqueued_jobs { SwapMatcher.new(@company).refresh_all }

    assert_equal 0, Match.count
    assert_equal false, JobSimilarity.sole.similar
  end

  test "editing a job description re-checks only the pairs that involve it" do
    nurse_pair
    perform_enqueued_jobs { SwapMatcher.new(@company).refresh_all }
    assert_equal 1, @calls.size

    @company.job_profiles.create!(title_key: "rn", title: "RN", description: "Bedside nursing, RN license required")
    assert_not JobSimilarity.sole.fresh?
    assert Match.sole.pending?, "the existing match is kept while the job is re-checked"

    perform_enqueued_jobs { SwapMatcher.new(@company).refresh_all }
    assert_equal 2, @calls.size
    assert_match "RN license required", @calls.last
    assert JobSimilarity.sole.fresh?
  end

  test "HR overrides win and are never sent to the AI" do
    create_employee(@company, from: "North", to: "South", title: "RN")
    create_employee(@company, from: "South", to: "North", title: "LPN")
    job_a, job_b = JobSimilarity.pair("RN", "LPN")
    @company.job_similarities.create!(job_a: job_a, job_b: job_b, source: "manual", similar: true, status: "done")

    perform_enqueued_jobs { SwapMatcher.new(@company).refresh_all }
    assert_equal "similar_job", Match.sole.match_type
    assert_empty @calls
  end

  test "a pair already being checked isn't queued twice" do
    nurse_pair
    SwapMatcher.new(@company).refresh_all
    SwapMatcher.new(@company).refresh_all
    assert_enqueued_jobs 1, only: JobComparisonJob
  end

  test "failures are recorded and retried later, not immediately" do
    nurse_pair
    JobComparer.responder = ->(_prompt) { raise "API down" }
    perform_enqueued_jobs { SwapMatcher.new(@company).refresh_all }
    assert_equal "failed", JobSimilarity.sole.status
    assert_equal 0, Match.count

    SwapMatcher.new(@company).refresh_all
    assert_no_enqueued_jobs only: JobComparisonJob

    travel JobSimilarity::RETRY_AFTER + 1.minute do
      SwapMatcher.new(@company).refresh_all
      assert_enqueued_jobs 1, only: JobComparisonJob
    end
  end

  test "with AI matching off, only identical titles match and nothing is sent" do
    @company.update!(ai_job_matching: false)
    nurse_pair
    perform_enqueued_jobs { SwapMatcher.new(@company).refresh_all }
    assert_equal 0, Match.count
    assert_empty @calls
  end

  test "only job information is sent to the AI, never employee names" do
    a, b = nurse_pair
    perform_enqueued_jobs { SwapMatcher.new(@company).refresh_all }
    assert_no_match a.name, @calls.first
    assert_no_match b.name, @calls.first
  end
end
