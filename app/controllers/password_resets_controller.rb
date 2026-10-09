class PasswordResetsController < ApplicationController
  rate_limit to: 5, within: 10.minutes, only: :create,
             with: -> { redirect_to new_password_reset_path, alert: "Too many requests. Please try again later." }

  before_action :find_user_by_token, only: %i[edit update]

  def new
  end

  def create
    if (user = User.find_by(email: params[:email].to_s.strip.downcase))
      UserMailer.with(user: user).password_reset.deliver_later
    end
    # Same message either way so the form can't be used to discover accounts.
    redirect_to sign_in_path, notice: "If that email has an account, a reset link is on its way."
  end

  def edit
  end

  def update
    if @user.update(params.require(:user).permit(:password, :password_confirmation).merge(activated_at: @user.activated_at || Time.current))
      redirect_to sign_in_path, notice: "Password reset. Please sign in."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def find_user_by_token
    @user = User.find_by_token_for(:password_reset, params[:token])
    redirect_to new_password_reset_path, alert: "That reset link is invalid or has expired. Please request a new one." unless @user
  end
end
