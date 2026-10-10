require "csv"

class EmployeesController < ApplicationController
  SORTABLE = {
    "name" => "employees.name", "job_title" => "employees.job_title", "job_code" => "employees.job_code",
    "seniority" => "employees.seniority", "current" => "current_locations.name", "desired" => "desired_locations.name"
  }.freeze

  before_action :require_manager
  before_action :set_employee, only: %i[show edit update destroy invite]

  def index
    scope = current_company.employees
                           .left_joins(:current_location, :desired_location)
                           .includes(:current_location, :desired_location, :user)
    scope = scope.where("employees.name LIKE :q OR employees.email LIKE :q OR employees.job_title LIKE :q", q: "%#{Employee.sanitize_sql_like(params[:q])}%") if params[:q].present?
    scope = scope.where(job_title: params[:job_title]) if params[:job_title].present?
    scope = scope.where(current_location_id: params[:current_location_id]) if params[:current_location_id].present?
    scope = scope.where(desired_location_id: params[:desired_location_id]) if params[:desired_location_id].present?
    scope = scope.seeking if params[:seeking] == "1"

    @sort = SORTABLE.key?(params[:sort]) ? params[:sort] : "name"
    @direction = params[:direction] == "desc" ? "desc" : "asc"
    @employees = scope.order(Arel.sql("#{SORTABLE[@sort]} #{@direction}"), "employees.id")
    @job_titles = current_company.employees.distinct.order(:job_title).pluck(:job_title)
    @locations = current_company.locations.ordered
  end

  def show
    @matches = @employee.all_matches.includes(:employee, :matched_employee).order(created_at: :desc)
  end

  def new
    @employee = current_company.employees.new
  end

  def create
    @employee = current_company.employees.new(employee_params)
    if @employee.save
      found = SwapMatcher.new(current_company).refresh(@employee)
      audit("employee.created", subject: @employee, summary: "Added #{@employee.name}")
      redirect_to @employee, notice: [ "#{@employee.name} was added.", match_notice(found) ].compact.join(" ")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @employee.update(employee_params)
      found = SwapMatcher.new(current_company).refresh(@employee)
      audit("employee.updated", subject: @employee, summary: "Updated #{@employee.name}")
      redirect_to @employee, notice: [ "#{@employee.name} was updated.", match_notice(found) ].compact.join(" ")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @employee.destroy
    audit("employee.deleted", summary: "Removed #{@employee.name}")
    redirect_to employees_path, notice: "#{@employee.name} was removed."
  end

  # Gives the employee a login so they can manage their own transfer request.
  def invite
    if @employee.user
      redirect_to @employee, alert: "#{@employee.name} already has an account."
    elsif @employee.email.blank?
      redirect_to edit_employee_path(@employee), alert: "Add an email address for #{@employee.name} first."
    elsif User.exists?(email: @employee.email)
      redirect_to @employee, alert: "#{@employee.email} is already used by another Swapper account."
    else
      user = StaffInviter.new(company: current_company, inviter: Current.user)
                         .invite(email: @employee.email, name: @employee.name, role: "employee", employee: @employee)
      if user.persisted?
        redirect_to @employee, notice: "Invitation sent to #{@employee.email}."
      else
        redirect_to @employee, alert: user.errors.full_messages.to_sentence
      end
    end
  end

  def import_form
  end

  def import
    file = params[:file]
    if file.blank?
      redirect_to import_employees_path, alert: "Choose a CSV file to upload."
      return
    end

    @result = EmployeeImporter.new(current_company).import(file.read)
    created = SwapMatcher.new(current_company).refresh_all if @result.imported.positive?
    audit("employee.imported", summary: "Imported #{@result.imported} employees from CSV")
    flash.now[:notice] = "Imported #{@result.imported} employees. #{match_notice(created.to_i)}".strip
    render :import_form
  end

  def template
    csv = CSV.generate do |rows|
      extra = current_company.rules.same_fields
      rows << EmployeeImporter::HEADERS + extra
      rows << [ "Jordan Smith", "jordan@example.com", "Registered Nurse", "RN2", 7, "North Clinic", "South Clinic" ] + extra.map { "" }
    end
    send_data csv, filename: "swapper-employees-template.csv", type: "text/csv"
  end

  private

  def set_employee
    @employee = current_company.employees.find(params[:id])
  end

  def employee_params
    params.require(:employee).permit(:name, :email, :job_title, :job_code, :seniority,
                                     :current_location_id, :desired_location_id, :request_note, custom_fields: {})
  end

  def match_notice(found)
    count = found.is_a?(Array) ? found.size : found.to_i
    "#{count} new swap #{"match".pluralize(count)} found." if count.positive?
  end
end
