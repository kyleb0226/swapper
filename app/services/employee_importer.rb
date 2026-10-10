require "csv"

# Bulk-loads employees from a CSV export (HRIS, spreadsheet, etc.).
# Unknown locations are created automatically. Rows are matched to existing
# employees by email so the same file can be re-uploaded to update records.
# Any extra columns (shift, department, license…) are kept as custom fields
# that the company's matching rules can use.
class EmployeeImporter
  HEADERS = %w[name email job_title job_code seniority current_location desired_location].freeze
  MAX_ROWS = 5_000

  Result = Struct.new(:imported, :errors)

  def initialize(company)
    @company = company
  end

  def import(data)
    result = Result.new(0, [])
    rows = CSV.parse(data.to_s.encode("UTF-8", invalid: :replace, undef: :replace).delete_prefix("﻿"),
                     headers: true, header_converters: ->(h) { h.to_s.strip.downcase.tr(" ", "_") })

    missing = %w[name job_title current_location] - rows.headers.compact
    if missing.any?
      result.errors << "Missing required column(s): #{missing.join(", ")}. Download the template to see the expected format."
      return result
    end
    if rows.size > MAX_ROWS
      result.errors << "That file has #{rows.size} rows. Please split it into files of #{MAX_ROWS} rows or fewer."
      return result
    end

    rows.each.with_index(2) do |row, line|
      employee = find_or_build(row["email"])
      extra = row.to_h.except(*HEADERS).reject { |key, _| key.blank? }
      employee.assign_attributes(
        custom_fields: (employee.custom_fields || {}).merge(extra.transform_values(&:to_s)),
        name: row["name"], email: row["email"], job_title: row["job_title"], job_code: row["job_code"],
        seniority: row["seniority"].presence || employee.seniority || 0,
        current_location: location(row["current_location"]),
        desired_location: location(row["desired_location"])
      )
      if employee.save
        result.imported += 1
      else
        result.errors << "Row #{line}: #{employee.errors.full_messages.to_sentence}"
      end
    end
    result
  rescue CSV::MalformedCSVError => e
    result.errors << "Couldn't read that file as CSV (#{e.message})."
    result
  end

  private

  def find_or_build(email)
    (email.present? && @company.employees.find_by(email: email.strip.downcase)) || @company.employees.new
  end

  def location(name)
    return if name.blank?

    @company.locations.where("LOWER(name) = ?", name.squish.downcase).first || @company.locations.create(name: name)
  end
end
