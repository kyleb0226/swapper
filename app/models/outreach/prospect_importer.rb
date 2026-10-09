require "csv"

module Outreach
  # Imports prospects from a CSV (exports from Apollo, ZoomInfo, LinkedIn Sales
  # Navigator, a state vendor list, a spreadsheet you built...). Column names are
  # matched loosely, e.g. "Company", "Company Name" and "Organization" all work.
  class ProspectImporter
    COLUMN_ALIASES = {
      organization: %w[organization company company_name account account_name agency employer],
      contact_name: %w[contact_name name full_name contact],
      first_name: %w[first_name firstname],
      last_name: %w[last_name lastname],
      contact_title: %w[contact_title title job_title position],
      email: %w[email email_address work_email],
      phone: %w[phone phone_number work_phone],
      website: %w[website url domain company_website],
      sector: %w[sector industry],
      city: %w[city],
      state: %w[state region province],
      notes: %w[notes]
    }.freeze

    Result = Struct.new(:imported, :errors)

    def import(data, source: nil)
      result = Result.new(0, [])
      rows = CSV.parse(data.to_s.encode("UTF-8", invalid: :replace, undef: :replace).delete_prefix("﻿"),
                       headers: true, header_converters: ->(h) { h.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").delete_suffix("_") })

      rows.each.with_index(2) do |row, line|
        attrs = extract(row)
        attrs[:contact_name] ||= [ attrs.delete(:first_name), attrs.delete(:last_name) ].compact.join(" ").presence
        attrs.delete(:first_name)
        attrs.delete(:last_name)
        attrs[:source] = source.presence || "CSV import"

        prospect = (attrs[:email].present? && Prospect.find_by(email: attrs[:email].strip.downcase)) || Prospect.new
        prospect.assign_attributes(attrs.compact)
        if prospect.save
          result.imported += 1
        else
          result.errors << "Row #{line}: #{prospect.errors.full_messages.to_sentence}"
        end
      end
      result
    rescue CSV::MalformedCSVError => e
      result.errors << "Couldn't read that file as CSV (#{e.message})."
      result
    end

    private

    def extract(row)
      COLUMN_ALIASES.to_h do |field, names|
        header = names.find { |name| row.headers.include?(name) && row[name].present? }
        [ field, header && row[header].to_s.strip ]
      end
    end
  end
end
