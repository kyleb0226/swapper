# State changes HR makes to a match, plus their side effects
# (clearing competing proposals, moving employees, notifications, audit log).
class SwapWorkflow
  class InvalidTransition < StandardError; end

  def initialize(match, actor:)
    @match = match
    @actor = actor
  end

  def approve!
    transition!(from: "pending", to: "approved") do
      competing_pending.destroy_all
    end
    notify(:approved)
    audit("match.approved", "Approved swap between #{names}")
  end

  def reject!
    transition!(from: "pending", to: "rejected")
    audit("match.rejected", "Rejected swap between #{names}")
  end

  # Moves an approved or rejected match back to pending and re-runs matching
  # for both employees so any options cleared at approval come back.
  def reopen!
    transition!(from: %w[approved rejected], to: "pending")
    matcher = SwapMatcher.new(@match.company)
    @match.employees.each { |employee| matcher.refresh(employee.reload) }
    audit("match.reopened", "Reopened swap between #{names}")
  end

  # Records that the swap happened: each employee now works at the other's
  # former location and their transfer requests are closed.
  def complete!
    a, b = @match.employee, @match.matched_employee
    transition!(from: "approved", to: "completed") do
      a_location, b_location = a.current_location_id, b.current_location_id
      a.update!(current_location_id: b_location, desired_location_id: nil, request_note: nil)
      b.update!(current_location_id: a_location, desired_location_id: nil, request_note: nil)
      @match.update!(completed_at: Time.current)
      competing_pending.destroy_all
    end
    notify(:completed)
    audit("match.completed", "Completed swap between #{names}")
  end

  private

  def transition!(from:, to:)
    raise InvalidTransition, "This match is #{@match.status}." unless Array(from).include?(@match.status)

    Match.transaction do
      @match.update!(status: to, decided_by: @actor, decided_at: Time.current)
      yield if block_given?
    end
  end

  def competing_pending
    ids = [ @match.employee_id, @match.matched_employee_id ]
    Match.pending.where.not(id: @match.id)
         .where("employee_id IN (:ids) OR matched_employee_id IN (:ids)", ids: ids)
  end

  def notify(event)
    @match.employees.each do |employee|
      next if employee.email.blank?

      MatchMailer.with(match: @match, employee: employee).public_send(event).deliver_later
    end
  end

  def names
    @match.employees.map(&:name).to_sentence
  end

  def audit(action, summary)
    AuditEvent.record(action, subject: @match, summary: summary, user: @actor, company: @match.company)
  end
end
