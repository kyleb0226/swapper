class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :locations, dependent: :destroy
  has_many :employees, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_many :audit_events, dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
end
