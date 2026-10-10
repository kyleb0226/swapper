class User < ApplicationRecord
  # Company roles, lowest to highest. Each role can do everything the roles before it can.
  #   employee - a worker: manages their own transfer request
  #   manager  - supervisor: manages employees and reviews matches
  #   admin    - HR head: also manages locations, staff accounts and sees the audit log
  ROLES = %w[employee manager admin].freeze
  ROLE_LABELS = { "employee" => "Employee", "manager" => "Manager", "admin" => "HR Admin" }.freeze

  has_secure_password

  belongs_to :company, optional: true
  has_one :employee, dependent: :nullify

  delegate :name, to: :company, prefix: true, allow_nil: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :company, presence: true, unless: :platform_admin?

  generates_token_for :password_reset, expires_in: 30.minutes do
    password_salt.last(10)
  end

  generates_token_for :invitation, expires_in: 7.days do
    activated_at
  end

  def role_at_least?(minimum)
    ROLES.index(role) >= ROLES.index(minimum.to_s)
  end

  def manager? = role_at_least?(:manager)
  def admin? = role_at_least?(:admin)

  def role_label
    ROLE_LABELS.fetch(role)
  end

  def display_name
    name.presence || email
  end

  def pending_invitation?
    invited_at.present? && activated_at.nil?
  end
end
