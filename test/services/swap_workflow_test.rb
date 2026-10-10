require "test_helper"

class SwapWorkflowTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @company = create_company
    @hr = create_user(@company)
    @a = create_employee(@company, from: "North", to: "South", email: "a@example.com")
    @b = create_employee(@company, from: "South", to: "North", email: "b@example.com")
    @c = create_employee(@company, from: "South", to: "North") # competes with b for a
    SwapMatcher.new(@company).refresh_all
    @match = Match.find_by!(employee: @a, matched_employee: @b)
  end

  test "approving clears competing pending options and emails both employees" do
    assert_equal 2, Match.pending.count

    assert_enqueued_emails 2 do
      SwapWorkflow.new(@match, actor: @hr).approve!
    end

    assert @match.reload.approved?
    assert_equal @hr, @match.decided_by
    assert_equal 1, Match.count
    assert AuditEvent.exists?(action: "match.approved", company: @company)
  end

  test "completing swaps locations and closes both requests" do
    workflow = SwapWorkflow.new(@match, actor: @hr)
    workflow.approve!
    workflow.complete!

    assert @match.reload.completed?
    assert_equal "South", @a.reload.current_location.name
    assert_equal "North", @b.reload.current_location.name
    assert_nil @a.desired_location
    assert_nil @b.swap_requested_at
  end

  test "reopening an approval brings back competing options" do
    workflow = SwapWorkflow.new(@match, actor: @hr)
    workflow.approve!
    workflow.reopen!

    assert @match.reload.pending?
    assert_equal 2, Match.pending.count
  end

  test "invalid transitions raise" do
    assert_raises(SwapWorkflow::InvalidTransition) { SwapWorkflow.new(@match, actor: @hr).complete! }
  end
end
