class MatchMailer < ApplicationMailer
  before_action do
    @match = params[:match]
    @employee = params[:employee]
    @partner = @match.other_employee(@employee)
  end

  def approved
    mail to: @employee.email, subject: "Your transfer swap was approved"
  end

  def completed
    mail to: @employee.email, subject: "Your transfer swap is complete"
  end
end
