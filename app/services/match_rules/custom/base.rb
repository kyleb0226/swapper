class MatchRules
  module Custom
    # Subclass this for one customer's quirk. Override `allows?` and set a
    # NAME and DESCRIPTION; the key is derived from the class name
    # (MatchRules::Custom::SameUnionLocal -> "same_union_local").
    class Base
      NAME = "Custom rule"
      DESCRIPTION = ""

      def self.key = name.demodulize.underscore
      def self.label = const_get(:NAME)
      def self.description = const_get(:DESCRIPTION)

      def name = self.class.label

      # Return false to stop these two employees from being matched.
      def allows?(_a, _b)
        true
      end
    end
  end
end
