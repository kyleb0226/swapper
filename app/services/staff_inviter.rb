# Creates an account for a staff member and emails them a link to set their password.
class StaffInviter
  def initialize(company:, inviter:)
    @company = company
    @inviter = inviter
  end

  # Returns the user; check #persisted? and #errors.
  def invite(email:, role:, name: nil, employee: nil)
    user = @company.users.new(email: email, name: name.presence || employee&.name, role: role,
                              password: SecureRandom.base58(32), invited_at: Time.current)
    User.transaction do
      user.save!
      employee&.update!(user: user) if employee && employee.user_id.nil?
    end
    UserMailer.with(user: user, inviter: @inviter).invitation.deliver_later
    AuditEvent.record("user.invited", subject: user, summary: "Invited #{user.email} as #{user.role_label}",
                      user: @inviter, company: @company)
    user
  rescue ActiveRecord::RecordInvalid
    user
  end
end
