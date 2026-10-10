# Custom matching rules

Swapper sells "matching that follows your rules". Most requests are covered by
the **standard rules** each HR Admin can set in *Company settings → Matching rules*:

| Rule | Stored as (`companies.match_rules`) |
|---|---|
| Minimum seniority to swap | `"min_seniority" => 5` |
| Max seniority difference | `"max_seniority_gap" => 3` |
| Same job code only | `"same_job_code_only" => true` |
| Must also match on custom fields | `"same_fields" => ["shift", "license"]` |

Custom fields (`employees.custom_fields`) come from any extra column in the CSV
import, or from the employee form once a field is listed in `same_fields`.

## When a customer needs something else

Requests arrive in **/admin → Custom requests** (and by email to `CONTACT_EMAIL`).
If no standard rule fits, write a bespoke rule:

1. Add a class in `app/services/match_rules/custom/`, e.g.
   `same_union_local.rb`:

   ```ruby
   class MatchRules
     module Custom
       # Metro Transit: operators may only swap within the same union local,
       # and never during the first 6 months after hire.
       class SameUnionLocal < Base
         NAME = "Same union local, 6+ months in role"
         DESCRIPTION = "Built for Metro Transit (request #12)."

         def allows?(a, b)
           a.custom_field("union_local").present? &&
             a.custom_field("union_local") == b.custom_field("union_local") &&
             [ a, b ].all? { |e| months_in_role(e) >= 6 }
         end

         private

         def months_in_role(employee)
           hired = Date.parse(employee.custom_field("hire_date").to_s) rescue nil
           hired ? ((Date.current - hired) / 30).floor : 0
         end
       end
     end
   end
   ```

2. Add a test next to `test/services/match_rules_test.rb` covering the
   customer's examples (who should and shouldn't match).
3. Deploy, then on **/admin → Customers → (company)** pick the rule under
   *Custom rule for this customer*. Saving re-runs matching for that company.

A custom rule only ever *removes* candidate pairs on top of the standard
checks; it runs only for the company it's assigned to. Tightening rules drops
pending suggestions that no longer fit but never undoes a swap HR approved.
