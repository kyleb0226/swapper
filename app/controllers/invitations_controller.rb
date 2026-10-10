# Lets an invited staff member choose a password and activate their account.
class InvitationsController < ApplicationController
  before_action :find_user_by_token

  def edit
  end

  def update
    attrs = params.require(:user).permit(:name, :password, :password_confirmation)
    if attrs[:password].blank?
      @user.errors.add(:password, "can't be blank")
      render :edit, status: :unprocessable_entity
    elsif @user.update(attrs.merge(activated_at: Time.current))
      sign_in(@user)
      AuditEvent.record("user.activated", subject: @user, summary: "#{@user.email} accepted their invitation")
      redirect_to home_path_for(@user), notice: "Welcome to Swapper!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def find_user_by_token
    @user = User.find_by_token_for(:invitation, params[:token])
    redirect_to sign_in_path, alert: "That invitation link is invalid, expired, or already used. Ask your HR admin to resend it." unless @user
  end
end
