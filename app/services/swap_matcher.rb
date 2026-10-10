# Finds employees who can trade locations with each other.
#
# Two employees match when, within the same company:
#   * both are asking for a transfer,
#   * each one's desired location is the other's current location,
#   * neither is already locked into an approved swap, and
#   * they hold the same job title (case-insensitive) or, when the company has
#     AI job matching turned on, jobs that are similar enough to swap, and
#   * they pass the company's matching rules (MatchRules: seniority limits,
#     same job code, same shift/department/…, or a customer's bespoke rule).
#
# Same job code is labelled "job_code" (the strongest match), same title
# "job_title", and AI-judged similar jobs "similar_job". Pairs HR rejected are
# never proposed again.
#
# Job similarity answers are cached in JobSimilarity. A pair of job titles that
# has no current answer is queued for one background AI comparison
# (JobComparisonJob) instead of blocking matching; the matcher runs again for
# those jobs once the answer arrives.
class SwapMatcher
  def initialize(company)
    @company = company
    @ai = company.ai_job_matching? && JobComparer.available?
    @to_compare = Set.new
    @rules = MatchRules.new(company)
  end

  # Re-evaluates one employee: drops their matches that no longer qualify
  # (e.g. they changed their desired location) and creates new ones.
  # Returns the newly created matches.
  def refresh(employee)
    created = refresh_one(employee)
    queue_comparisons
    created
  end

  # Re-evaluates every employee in the company. Returns the number of new matches.
  def refresh_all
    created = @company.employees.find_each.sum { |employee| refresh_one(employee).size }
    queue_comparisons
    created
  end

  # Re-evaluates everyone holding one of these job titles (lowercase keys).
  def refresh_titles(title_keys)
    created = @company.employees.where("LOWER(job_title) IN (?)", title_keys).find_each.sum { |employee| refresh_one(employee).size }
    queue_comparisons
    created
  end

  private

  def refresh_one(employee)
    prune_stale(employee).each { |other| refresh_one(other) }
    return [] unless eligible?(employee)

    candidates_for(employee).filter_map { |other| propose(employee, other) }
  end

  def eligible?(employee)
    employee.seeking_swap? && !employee.locked_in_swap?
  end

  def candidates_for(employee)
    @company.employees
            .where(current_location_id: employee.desired_location_id, desired_location_id: employee.current_location_id)
            .where.not(id: employee.id)
            .reject(&:locked_in_swap?)
            .select { |other| @rules.allows?(employee, other) }
            .select { |other| same_job?(employee, other) || similar_job_for_new_match?(employee, other) }
  end

  def same_job?(a, b)
    a.job_title.casecmp?(b.job_title)
  end

  def similar_job_for_new_match?(a, b)
    return false unless @ai

    row = JobSimilarity.lookup(@company, a.job_title, b.job_title)
    @to_compare << JobSimilarity.pair(a.job_title, b.job_title) if row.nil? || row.needs_comparison?
    row&.approves_new_match? || false
  end

  def qualifies?(a, b)
    return false unless a.desired_location_id == b.current_location_id && b.desired_location_id == a.current_location_id
    return true if same_job?(a, b)

    # An existing similar-job match survives while a changed job is re-checked;
    # it is dropped only if HR or the AI decides the jobs aren't similar.
    row = JobSimilarity.lookup(@company, a.job_title, b.job_title)
    @to_compare << JobSimilarity.pair(a.job_title, b.job_title) if @ai && row&.needs_comparison?
    row&.keeps_existing_match? || false
  end

  def propose(a, b)
    first, second = [ a, b ].sort_by(&:id)
    return if Match.exists?(employee_id: first.id, matched_employee_id: second.id)

    type = if !same_job?(first, second) then "similar_job"
    elsif first.job_code.present? && first.job_code.casecmp?(second.job_code.to_s) then "job_code"
    else "job_title"
    end
    Match.create!(company: @company, employee: first, matched_employee: second, match_type: type, status: "pending")
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    nil
  end

  # Removes matches that no longer hold. Returns the other employees from any
  # dropped *approved* match, since they may now be free to match elsewhere.
  def prune_stale(employee)
    freed = []
    Match.involving(employee).where.not(status: "completed").includes(:employee, :matched_employee).find_each do |match|
      # Tightened rules only drop *pending* suggestions; a swap HR already
      # approved stands.
      next if qualifies?(match.employee, match.matched_employee) &&
              (!match.pending? || @rules.allows?(match.employee, match.matched_employee))

      freed << match.other_employee(employee) if match.approved?
      match.destroy
    end
    freed
  end

  # Marks the pairs as requested (so they aren't queued twice) and sends them
  # to the AI in one background job.
  def queue_comparisons
    return if @to_compare.empty?

    pairs = @to_compare.to_a
    @to_compare.clear
    now = Time.current
    pairs.each do |job_a, job_b|
      row = @company.job_similarities.find_or_initialize_by(job_a: job_a, job_b: job_b)
      next if row.manual?

      row.update!(requested_at: now, status: row.status == "done" && row.fresh? ? "done" : "pending")
    end
    JobComparisonJob.perform_later(@company, pairs)
  end
end
