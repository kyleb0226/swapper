# AI job matching: HR can describe each job, and the result of comparing two
# job titles is cached so the same pair is never sent to the AI twice unless
# one of the two jobs changes (tracked with a fingerprint).
class CreateJobSimilarities < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :ai_job_matching, :boolean, null: false, default: false

    create_table :job_profiles do |t|
      t.references :company, null: false, foreign_key: true
      t.string :title_key, null: false
      t.string :title, null: false
      t.text :description
      t.timestamps
    end
    add_index :job_profiles, [ :company_id, :title_key ], unique: true

    create_table :job_similarities do |t|
      t.references :company, null: false, foreign_key: true
      t.string :job_a, null: false
      t.string :job_b, null: false
      t.string :fingerprint
      t.string :status, null: false, default: "pending"
      t.string :source, null: false, default: "ai"
      t.integer :score
      t.boolean :similar
      t.text :reason
      t.string :model
      t.datetime :requested_at
      t.datetime :compared_at
      t.timestamps
    end
    add_index :job_similarities, [ :company_id, :job_a, :job_b ], unique: true
  end
end
