# Self-serve sign up. Each sign up creates a brand new company workspace and
# makes the person its HR Admin. Other staff join by invitation only, so nobody
# can see a company's data just by typing its name.
class RegistrationsController < ApplicationController
  rate_limit to: 5, within: 10.minutes, only: :create,
             with: -> { redirect_to sign_up_path, alert: "Too many sign up attempts. Please try again later." }

  def new
    redirect_to home_path_for(Current.user) and return if signed_in?

    @user = User.new
  end

  def create
    @company = Company.new(name: params.dig(:user, :company_name))
    @user = User.new(user_params.merge(role: "admin", activated_at: Time.current))
    @user.company = @company

    company_valid = @company.valid?
    if @user.valid? && company_valid
      User.transaction do
        @company.save!
        @user.save!
      end
      sign_in(@user)
      AuditEvent.record("company.created", subject: @company, summary: "Workspace created by #{@user.email}")
      redirect_to dashboard_path, notice: "Welcome to Swapper! Start by adding your locations."
    else
      @company.errors.each { |error| @user.errors.add(:company_name, error.message) }
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
