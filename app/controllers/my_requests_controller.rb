# Self-service page where any signed-in worker manages their own transfer request.
class MyRequestsController < ApplicationController
  before_action :require_company
  before_action :set_employee

  def show
  end

  def update
    if @employee.locked_in_swap?
      redirect_to my_request_path, alert: "Your swap has been approved by HR. Contact HR to make changes."
      return
    end

    attrs = params.require(:employee).permit(:desired_location_id, :request_note)
    if @employee.update(attrs)
      SwapMatcher.new(current_company).refresh(@employee)
      audit("employee.request_updated", subject: @employee,
            summary: @employee.seeking_swap? ? "#{@employee.name} requested #{@employee.desired_location.name}" : "#{@employee.name} withdrew their request")
      redirect_to my_request_path, notice: @employee.seeking_swap? ? "Your transfer request is saved." : "Your transfer request was withdrawn."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_employee
    @employee = Current.user.employee
    return if @employee

    render :unlinked
  end
end
