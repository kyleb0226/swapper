# Tables for the platform-owner outreach tool (prospect list + email sender).
# Everything is namespaced "outreach_" so it can be lifted into its own app later.
class CreateOutreachTables < ActiveRecord::Migration[8.1]
  def change
    create_table :outreach_prospects do |t|
      t.string :organization, null: false
      t.string :contact_name
      t.string :contact_title
      t.string :email
      t.string :phone
      t.string :website
      t.string :sector
      t.string :city
      t.string :state
      t.string :source
      t.string :status, null: false, default: "new"
      t.text :notes
      t.datetime :last_contacted_at
      t.datetime :unsubscribed_at
      t.timestamps
    end
    add_index :outreach_prospects, :email, unique: true, where: "email IS NOT NULL"
    add_index :outreach_prospects, :status

    create_table :outreach_email_templates do |t|
      t.string :name, null: false
      t.string :subject, null: false
      t.text :body, null: false
      t.timestamps
    end

    create_table :outreach_emails do |t|
      t.references :prospect, null: false, foreign_key: { to_table: :outreach_prospects }
      t.references :email_template, foreign_key: { to_table: :outreach_email_templates }
      t.string :to, null: false
      t.string :subject, null: false
      t.text :body, null: false
      t.string :status, null: false, default: "queued"
      t.text :error
      t.datetime :sent_at
      t.timestamps
    end
    add_index :outreach_emails, :created_at
  end
end
