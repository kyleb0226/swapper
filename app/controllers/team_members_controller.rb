# HR Admins manage who can sign in to their company's workspace and at what level.
class TeamMembersController < ApplicationController
  before_action :require_admin
  before_action :set_member, only: %i[edit update destroy resend_invitation]

  def index
    @members = current_company.users.includes(:employee).order(:role, :email)
  end

  def new
    @member = current_company.users.new(role: "manager")
  end

  def create
    employee = current_company.employees.find_by(email: params.dig(:user, :email).to_s.strip.downcase)
    @member = StaffInviter.new(company: current_company, inviter: Current.user)
                          .invite(**params.require(:user).permit(:email, :name, :role).to_h.symbolize_keys, employee: employee)
    if @member.persisted?
      redirect_to team_members_path, notice: "Invitation sent to #{@member.email}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @member == Current.user && params.dig(:user, :role) != "admin"
      redirect_to team_members_path, alert: "You can't remove your own HR Admin access. Ask another HR Admin."
    elsif @member.update(params.require(:user).permit(:name, :role))
      audit("user.role_changed", subject: @member, summary: "#{@member.email} is now #{@member.role_label}")
      redirect_to team_members_path, notice: "#{@member.display_name} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @member == Current.user
      redirect_to team_members_path, alert: "You can't remove yourself."
    else
      @member.destroy
      audit("user.removed", summary: "Removed access for #{@member.email}")
      redirect_to team_members_path, notice: "#{@member.email} no longer has access."
    end
  end

  def resend_invitation
    if @member.pending_invitation?
      UserMailer.with(user: @member, inviter: Current.user).invitation.deliver_later
      @member.update_column(:invited_at, Time.current)
      redirect_to team_members_path, notice: "Invitation re-sent to #{@member.email}."
    else
      redirect_to team_members_path, alert: "#{@member.email} has already joined."
    end
  end

  private

  def set_member
    @member = current_company.users.find(params[:id])
  end
end
