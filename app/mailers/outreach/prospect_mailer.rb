module Outreach
  class ProspectMailer < ApplicationMailer
    layout false

    def outreach
      @email = params[:email]
      @prospect = @email.prospect
      @unsubscribe_url = outreach_unsubscribe_url(@prospect.generate_token_for(:unsubscribe))
      @postal_address = Outreach.postal_address

      headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
      headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
      mail to: @email.to, from: Outreach.from_address, subject: @email.subject
    end
  end
end
