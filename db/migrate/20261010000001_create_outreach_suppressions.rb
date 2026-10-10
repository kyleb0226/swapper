# Permanent do-not-contact list. An address lands here automatically the first
# time it is emailed, when it unsubscribes or when it bounces; whole domains can
# be blocked by hand (e.g. an existing customer). Rows outlive deleted prospects.
class CreateOutreachSuppressions < ActiveRecord::Migration[8.1]
  def up
    create_table :outreach_suppressions do |t|
      t.string :email
      t.string :domain
      t.string :reason, null: false
      t.string :note
      t.timestamps
    end
    add_index :outreach_suppressions, :email, unique: true, where: "email IS NOT NULL"
    add_index :outreach_suppressions, :domain, unique: true, where: "domain IS NOT NULL"

    add_column :outreach_emails, :follow_up, :boolean, null: false, default: false

    # Backfill from history so nobody already emailed or unsubscribed slips through.
    execute <<~SQL
      INSERT INTO outreach_suppressions (email, reason, created_at, updated_at)
      SELECT DISTINCT LOWER(p.email), 'unsubscribed', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM outreach_prospects p WHERE p.email IS NOT NULL AND p.unsubscribed_at IS NOT NULL
    SQL
    execute <<~SQL
      INSERT INTO outreach_suppressions (email, reason, created_at, updated_at)
      SELECT DISTINCT LOWER(e."to"), 'contacted', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM outreach_emails e
      WHERE e.status IN ('queued', 'sent')
        AND LOWER(e."to") NOT IN (SELECT email FROM outreach_suppressions WHERE email IS NOT NULL)
    SQL
  end

  def down
    remove_column :outreach_emails, :follow_up
    drop_table :outreach_suppressions
  end
end
