class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "Swapper <no-reply@example.com>") }
  layout "mailer"
end
