# A proposed location swap between two employees of the same company.
#
# Lifecycle: pending -> approved -> completed
#                    \-> rejected
# A rejected pair is remembered so the matcher never proposes it again.
class Match < ApplicationRecord
  STATUSES = %w[pending approved rejected completed].freeze
  TYPES = { "job_code" => "Same job code", "job_title" => "Same job title" }.freeze

  belongs_to :company
  belongs_to :employee
  belongs_to :matched_employee, class_name: "Employee"
  belongs_to :decided_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :match_type, inclusion: { in: TYPES.keys }
  validates :matched_employee_id, uniqueness: { scope: :employee_id }

  STATUSES.each do |name|
    scope name, -> { where(status: name) }
    define_method("#{name}?") { status == name }
  end

  scope :involving, ->(employee) { where(employee_id: employee.id).or(where(matched_employee_id: employee.id)) }
  scope :in_progress, -> { where(status: %w[pending approved]) }

  def employees
    [ employee, matched_employee ]
  end

  def other_employee(employee_or_id)
    id = employee_or_id.is_a?(Employee) ? employee_or_id.id : employee_or_id
    employee_id == id ? matched_employee : employee
  end

  def type_label
    TYPES.fetch(match_type)
  end

  def combined_seniority
    employee.seniority + matched_employee.seniority
  end

  # Number of other pending options either employee has. HR uses this to see
  # where they are choosing between competing swaps.
  def competing_count
    Match.pending.where.not(id: id)
         .where("employee_id IN (:ids) OR matched_employee_id IN (:ids)", ids: [ employee_id, matched_employee_id ])
         .count
  end
end
