# Per-company matching rules (standard options HR can turn on, plus an optional
# bespoke rule the platform owner builds for one customer), extra per-employee
# fields those rules can compare (shift, department, license…), and the
# "custom solution" requests prospects send from the home page.
class AddMatchRulesAndCustomRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :match_rules, :json, null: false, default: {}
    add_column :companies, :custom_rule, :string
    add_column :employees, :custom_fields, :json, null: false, default: {}

    create_table :custom_requests do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :organization, null: false
      t.string :employee_count
      t.text :message, null: false
      t.string :status, null: false, default: "new"
      t.text :notes
      t.timestamps
    end
    add_index :custom_requests, :status
  end
end
