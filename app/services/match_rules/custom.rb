# Registry of bespoke matching rules built for individual customers.
#
# Each rule is a class in app/services/match_rules/custom/ that subclasses
# MatchRules::Custom::Base. The platform owner assigns one to a company from
# /admin/companies/:id. See docs/CUSTOM_RULES.md for how to write one.
class MatchRules
  module Custom
    def self.all
      Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/services/match_rules/custom").to_s)
      Base.descendants.reject { |klass| klass.name.nil? }.sort_by(&:name)
    end

    def self.keys
      all.map(&:key)
    end

    def self.find(key)
      return if key.blank?

      klass = all.find { |k| k.key == key }
      klass&.new
    end
  end
end
