# Public form: "we need Swapper to follow our rules". Saves the request and
# emails the owner. A hidden "website" field catches bots.
class CustomRequestsController < ApplicationController
  rate_limit to: 5, within: 1.hour, only: :create,
             with: -> { redirect_to custom_path, alert: "Too many requests. Please try again later or email us." }

  def new
    @custom_request = CustomRequest.new(prefill)
  end

  def create
    return redirect_to(custom_path(sent: 1)) if params[:website].present? # bot honeypot

    @custom_request = CustomRequest.new(custom_request_params)
    if @custom_request.save
      CustomRequestMailer.with(custom_request: @custom_request).received.deliver_later
      redirect_to custom_path(sent: 1)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def custom_request_params
    params.require(:custom_request).permit(:name, :email, :organization, :employee_count, :message)
  end

  def prefill
    return {} unless signed_in?

    { name: Current.user.try(:display_name), email: Current.user.email, organization: current_company&.name }
  end
end
