namespace :swapper do
  desc "Give a user access to the owner admin area (/admin). Creates the user if needed. EMAIL=you@example.com"
  task make_platform_admin: :environment do
    email = ENV.fetch("EMAIL") { abort "Usage: bin/rails swapper:make_platform_admin EMAIL=you@example.com" }
    user = User.find_by(email: email.strip.downcase)

    if user
      user.update!(platform_admin: true)
      puts "#{user.email} is now a platform admin."
    else
      password = SecureRandom.base58(16)
      User.create!(email: email, password: password, platform_admin: true, activated_at: Time.current)
      puts "Created platform admin #{email} with temporary password: #{password}"
      puts "Sign in and change it under Account settings."
    end
  end
end
