# Account settings: change your own name and password.
class PasswordsController < ApplicationController
  before_action :require_sign_in

  def edit
  end

  def update
    @user = Current.user
    if @user.authenticate(params.dig(:user, :current_password).to_s)
      if @user.update(params.require(:user).permit(:name, :password, :password_confirmation))
        redirect_to edit_password_path, notice: "Account updated."
      else
        render :edit, status: :unprocessable_entity
      end
    else
      @user.errors.add(:current_password, "is incorrect")
      render :edit, status: :unprocessable_entity
    end
  end
end
