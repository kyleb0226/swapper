# Idempotent: safe to run more than once.
#
# Every environment gets the starter outreach email templates.
# Development also gets a demo company with one login per role.

starter_templates = [
  {
    name: "Intro: public sector HR",
    subject: "Transfer requests at {{organization}}",
    body: <<~BODY
      Hi {{first_name}},

      I'm building Swapper, a small tool that helps agencies handle employee transfer requests. Employees say where they'd
      rather work, Swapper finds coworkers in the same job who want to trade places, and HR approves the swaps in
      seniority order, with a full audit trail.

      For agencies with many sites, it usually turns a spreadsheet-and-email process into a few clicks, and it helps with
      retention when people can get closer to home without leaving.

      Would a 15-minute walkthrough be useful for {{organization}}? If transfers aren't your area, I'd be grateful if you
      could point me to the right person.

      Thanks,
      Kyle
    BODY
  },
  {
    name: "Intro: healthcare systems",
    subject: "Nurse transfer requests across {{organization}}",
    body: <<~BODY
      Hi {{first_name}},

      Health systems lose good nurses and techs when a transfer request sits for months. Swapper matches staff who want to
      trade facilities (same role, each wanting the other's site), so both units stay fully staffed and two people get
      the move they asked for.

      HR sees every possible swap ranked by seniority and approves it in one click. Employees get an email when it's done.

      Could I show you how it would work for {{organization}}? 15 minutes is plenty.

      Best,
      Kyle
    BODY
  },
  {
    name: "Follow-up",
    subject: "Re: transfer requests at {{organization}}",
    body: <<~BODY
      Hi {{first_name}},

      Just following up on my note about Swapper. If location transfers aren't a pain point for {{organization}} right
      now, no problem at all; just let me know and I won't follow up again.

      Thanks,
      Kyle
    BODY
  }
]

starter_templates.each do |attrs|
  Outreach::EmailTemplate.find_or_create_by!(name: attrs[:name]) do |template|
    template.subject = attrs[:subject]
    template.body = attrs[:body]
  end
end

return unless Rails.env.development?

require "faker"

company = Company.find_or_create_by!(name: "Demo Health Network")
locations = [ "North Clinic", "South Clinic", "Downtown Hospital", "Riverside Hospital", "Lakeview Center" ].map do |name|
  company.locations.find_or_create_by!(name: name)
end

password = "password123"
{ "admin@example.com" => "admin", "manager@example.com" => "manager", "employee@example.com" => "employee" }.each do |email, role|
  User.find_or_create_by!(email: email) do |user|
    user.company = company
    user.name = "Demo #{role.capitalize}"
    user.role = role
    user.password = password
    user.activated_at = Time.current
  end
end

User.find_or_create_by!(email: "owner@example.com") do |user|
  user.name = "Platform Owner"
  user.platform_admin = true
  user.password = password
  user.activated_at = Time.current
end

if company.employees.none?
  Faker::Config.random = Random.new(42)
  jobs = [ [ "Registered Nurse", "RN2" ], [ "Registered Nurse", "RN3" ], [ "Medical Assistant", "MA1" ], [ "Radiology Tech", "RT1" ] ]
  60.times do
    title, code = jobs.sample
    current, desired = locations.sample(2)
    company.employees.create!(
      name: Faker::Name.name, email: Faker::Internet.unique.email(domain: "example.com"),
      job_title: title, job_code: code, seniority: rand(0..30),
      current_location: current, desired_location: (rand < 0.7 ? desired : nil)
    )
  end

  employee_user = User.find_by!(email: "employee@example.com")
  company.employees.first.update!(user: employee_user, email: employee_user.email)
  SwapMatcher.new(company).refresh_all
end

puts "Demo data ready. Sign in with admin@, manager@, employee@ or owner@example.com / #{password}"
