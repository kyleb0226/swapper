ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module TestData
  PASSWORD = "password123"

  def create_company(name = "Acme #{SecureRandom.hex(3)}", locations: %w[North South East])
    company = Company.create!(name: name)
    locations.each { |location| company.locations.create!(name: location) }
    company
  end

  def create_user(company, role: "admin", email: "#{role}-#{SecureRandom.hex(4)}@example.com", **attrs)
    User.create!(company: company, role: role, email: email, password: PASSWORD, activated_at: Time.current, **attrs)
  end

  def location(company, name)
    company.locations.find_by!(name: name)
  end

  def create_employee(company, from:, to: nil, title: "Nurse", code: "RN1", seniority: 5, **attrs)
    company.employees.create!(name: "Emp #{SecureRandom.hex(3)}", job_title: title, job_code: code, seniority: seniority,
                              current_location: location(company, from), desired_location: to && location(company, to), **attrs)
  end
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    include TestData
  end
end

module ActionDispatch
  class IntegrationTest
    def sign_in_as(user)
      post sign_in_path, params: { email: user.email, password: TestData::PASSWORD }
      assert_response :redirect
    end
  end
end
