# Finds employees who can trade locations with each other.
#
# Two employees match when, within the same company:
#   * both are asking for a transfer,
#   * each one's desired location is the other's current location,
#   * they hold the same job title (case-insensitive), and
#   * neither is already locked into an approved swap.
#
# Pairs with the same job code are labelled "job_code" (the strongest match);
# otherwise "job_title". Pairs HR rejected are never proposed again.
class SwapMatcher
  def initialize(company)
    @company = company
  end

  # Re-evaluates one employee: drops their matches that no longer qualify
  # (e.g. they changed their desired location) and creates new ones.
  # Returns the newly created matches.
  def refresh(employee)
    prune_stale(employee).each { |other| refresh(other) }
    return [] unless eligible?(employee)

    candidates_for(employee).filter_map { |other| propose(employee, other) }
  end

  # Re-evaluates every employee in the company. Returns the number of new matches.
  def refresh_all
    created = 0
    @company.employees.find_each do |employee|
      created += refresh(employee).size
    end
    created
  end

  private

  def eligible?(employee)
    employee.seeking_swap? && !employee.locked_in_swap?
  end

  def candidates_for(employee)
    @company.employees
            .where(current_location_id: employee.desired_location_id, desired_location_id: employee.current_location_id)
            .where("LOWER(job_title) = ?", employee.job_title.downcase)
            .where.not(id: employee.id)
            .reject(&:locked_in_swap?)
  end

  def qualifies?(a, b)
    a.desired_location_id == b.current_location_id &&
      b.desired_location_id == a.current_location_id &&
      a.job_title.casecmp?(b.job_title)
  end

  def propose(a, b)
    first, second = [ a, b ].sort_by(&:id)
    return if Match.exists?(employee_id: first.id, matched_employee_id: second.id)

    type = first.job_code.present? && first.job_code.casecmp?(second.job_code.to_s) ? "job_code" : "job_title"
    Match.create!(company: @company, employee: first, matched_employee: second, match_type: type, status: "pending")
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    nil
  end

  # Removes matches that no longer hold. Returns the other employees from any
  # dropped *approved* match, since they may now be free to match elsewhere.
  def prune_stale(employee)
    freed = []
    Match.involving(employee).where.not(status: "completed").includes(:employee, :matched_employee).find_each do |match|
      next if qualifies?(match.employee, match.matched_employee)

      freed << match.other_employee(employee) if match.approved?
      match.destroy
    end
    freed
  end
end
