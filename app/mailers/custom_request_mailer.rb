class CustomRequestMailer < ApplicationMailer
  # Tells the owner a new custom-solution request came in.
  def received
    @request = params[:custom_request]
    mail to: ENV.fetch("CONTACT_EMAIL", "kylebelfance@gmail.com"), reply_to: @request.email,
         subject: "Custom matching request: #{@request.organization}"
  end
end
