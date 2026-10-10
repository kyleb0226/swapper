# Extra conditions a company can put on who may swap with whom, applied on top
# of the basic match (each wants the other's location, same or similar job).
#
# Standard rules live in Company#match_rules and are set by HR in Company
# settings:
#   "min_seniority"      => Integer  both employees need at least this many years
#   "max_seniority_gap"  => Integer  their seniority may differ by at most this
#   "same_job_code_only" => Boolean  job codes must be present and equal
#   "same_fields"        => [String] Employee#custom_fields that must be equal
#                                    for both (e.g. "shift", "license")
#
# A company can also have one bespoke rule (Company#custom_rule), written for
# that customer as a class in app/services/match_rules/custom/ and assigned by
# the platform owner in /admin. See docs/CUSTOM_RULES.md.
class MatchRules
  FIELD_LIMIT = 10

  # "Night Shift " -> "night_shift"; anything else is dropped.
  def self.field_key(name)
    key = name.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").delete_prefix("_").delete_suffix("_")
    key.presence&.first(30)
  end

  # Turns form/JSON input into the stored shape, dropping empty values.
  def self.clean(raw)
    raw = (raw || {}).to_h.stringify_keys
    fields = Array(raw["same_fields"].is_a?(String) ? raw["same_fields"].split(",") : raw["same_fields"])
    {
      "min_seniority" => int_or_nil(raw["min_seniority"]),
      "max_seniority_gap" => int_or_nil(raw["max_seniority_gap"]),
      "same_job_code_only" => ActiveModel::Type::Boolean.new.cast(raw["same_job_code_only"]) || nil,
      "same_fields" => fields.filter_map { |f| field_key(f) }.uniq.first(FIELD_LIMIT).presence
    }.compact
  end

  def self.int_or_nil(value)
    Integer(value.to_s, exception: false)&.clamp(0, 99) if value.to_s.strip.present?
  end

  def initialize(company)
    @rules = company.match_rules || {}
    @custom = MatchRules::Custom.find(company.custom_rule)
  end

  def allows?(a, b)
    reasons_against(a, b).empty?
  end

  # Why these two may not swap (empty when they may). Used for tests and so the
  # UI can explain itself later.
  def reasons_against(a, b)
    reasons = []
    if (min = @rules["min_seniority"]) && [ a.seniority, b.seniority ].min < min
      reasons << "needs #{min}+ years of seniority"
    end
    if (gap = @rules["max_seniority_gap"]) && (a.seniority - b.seniority).abs > gap
      reasons << "seniority differs by more than #{gap} years"
    end
    if @rules["same_job_code_only"] && !(a.job_code.present? && a.job_code.casecmp?(b.job_code.to_s))
      reasons << "job codes must match"
    end
    Array(@rules["same_fields"]).each do |field|
      va, vb = a.custom_field(field), b.custom_field(field)
      reasons << "#{field.humanize.downcase} must match" unless va.present? && va.casecmp?(vb.to_s)
    end
    reasons << @custom.name unless @custom.nil? || @custom.allows?(a, b)
    reasons
  end

  def same_fields
    Array(@rules["same_fields"])
  end

  # Plain-English summary for settings pages, e.g. ["Same job code only", …].
  def describe
    list = []
    list << "At least #{@rules["min_seniority"]} years of seniority" if @rules["min_seniority"]
    list << "Seniority within #{@rules["max_seniority_gap"]} years of each other" if @rules["max_seniority_gap"]
    list << "Same job code only" if @rules["same_job_code_only"]
    same_fields.each { |f| list << "Same #{f.humanize.downcase}" }
    list << "#{@custom.name} (custom)" if @custom
    list
  end
end
