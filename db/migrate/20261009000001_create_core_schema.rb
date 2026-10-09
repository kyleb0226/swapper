# Consolidated schema. The original 2024 prototype migrations could not run
# from an empty database, so they were replaced by this single migration.
class CreateCoreSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :users do |t|
      t.references :company, foreign_key: true
      t.string :name
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "employee"
      t.boolean :platform_admin, null: false, default: false
      t.datetime :invited_at
      t.datetime :activated_at
      t.datetime :last_sign_in_at
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :locations do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :region
      t.timestamps
    end
    add_index :locations, [ :company_id, :name ], unique: true

    create_table :employees do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :email
      t.string :job_title, null: false
      t.string :job_code
      t.integer :seniority, null: false, default: 0
      t.references :current_location, null: false, foreign_key: { to_table: :locations }
      t.references :desired_location, foreign_key: { to_table: :locations }
      t.text :request_note
      t.datetime :swap_requested_at
      t.timestamps
    end
    add_index :employees, [ :company_id, :email ]

    create_table :matches do |t|
      t.references :company, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.references :matched_employee, null: false, foreign_key: { to_table: :employees }
      t.string :match_type, null: false
      t.string :status, null: false, default: "pending"
      t.references :decided_by, foreign_key: { to_table: :users }
      t.datetime :decided_at
      t.datetime :completed_at
      t.timestamps
    end
    add_index :matches, [ :employee_id, :matched_employee_id ], unique: true
    add_index :matches, [ :company_id, :status ]

    create_table :audit_events do |t|
      t.references :company, foreign_key: true
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.string :subject_type
      t.bigint :subject_id
      t.string :summary
      t.datetime :created_at, null: false
    end
    add_index :audit_events, [ :company_id, :created_at ]
  end
end
