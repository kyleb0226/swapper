class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to sign_in_path, alert: "Too many attempts. Please wait a few minutes and try again." }

  def new
    redirect_to home_path_for(Current.user) if signed_in?
  end

  def create
    user = User.authenticate_by(email: params[:email].to_s.strip.downcase, password: params[:password].to_s)

    if user&.pending_invitation?
      flash.now[:alert] = "Please accept your invitation email to finish setting up your account."
      render :new, status: :unprocessable_entity
    elsif user
      return_to = session[:return_to]
      sign_in(user)
      redirect_to return_to || home_path_for(user), notice: "Signed in."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out."
  end
end
