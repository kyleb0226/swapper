class LocationsController < ApplicationController
  before_action :require_admin
  before_action :set_location, only: %i[edit update destroy]

  def index
    @locations = current_company.locations.ordered
    @headcounts = current_company.employees.group(:current_location_id).count
    @demand = current_company.employees.seeking.group(:desired_location_id).count
  end

  def new
    @location = current_company.locations.new
  end

  def create
    @location = current_company.locations.new(location_params)
    if @location.save
      audit("location.created", subject: @location, summary: "Added location #{@location.name}")
      redirect_to locations_path, notice: "#{@location.name} was added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @location.update(location_params)
      audit("location.updated", subject: @location, summary: "Updated location #{@location.name}")
      redirect_to locations_path, notice: "#{@location.name} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @location.destroy
      audit("location.deleted", summary: "Removed location #{@location.name}")
      SwapMatcher.new(current_company).refresh_all
      redirect_to locations_path, notice: "#{@location.name} was removed."
    else
      redirect_to locations_path, alert: "#{@location.name} can't be removed while employees are assigned to it."
    end
  end

  private

  def set_location
    @location = current_company.locations.find(params[:id])
  end

  def location_params
    params.require(:location).permit(:name, :region)
  end
end
