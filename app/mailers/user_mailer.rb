class UserMailer < ApplicationMailer
  def password_reset
    @user = params[:user]
    @token = @user.generate_token_for(:password_reset)
    mail to: @user.email, subject: "Reset your Swapper password"
  end

  def invitation
    @user = params[:user]
    @inviter = params[:inviter]
    @token = @user.generate_token_for(:invitation)
    mail to: @user.email, subject: "You're invited to #{@user.company_name} on Swapper"
  end
end
