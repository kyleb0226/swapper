class Location < ApplicationRecord
  belongs_to :company
  has_many :current_employees, class_name: "Employee", foreign_key: :current_location_id, dependent: :restrict_with_error
  has_many :requesting_employees, class_name: "Employee", foreign_key: :desired_location_id, dependent: :nullify

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, uniqueness: { scope: :company_id, case_sensitive: false }, length: { maximum: 120 }

  scope :ordered, -> { order(:name) }

  def to_s = name
end
