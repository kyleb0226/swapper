module Admin
  module Outreach
    class ProspectsController < BaseController
      before_action :set_prospect, only: %i[show edit update destroy]

      def index
        scope = ::Outreach::Prospect.ordered
        scope = scope.where("organization LIKE :q OR contact_name LIKE :q OR email LIKE :q", q: "%#{::Outreach::Prospect.sanitize_sql_like(params[:q])}%") if params[:q].present?
        scope = scope.where(sector: params[:sector]) if params[:sector].present?
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(state: params[:state].upcase) if params[:state].present?
        @prospects = scope.limit(500)
      end

      def show
        @emails = @prospect.emails.recent
      end

      def new
        @prospect = ::Outreach::Prospect.new(sector: params[:sector], source: params[:source])
      end

      def create
        @prospect = ::Outreach::Prospect.new(prospect_params)
        if @prospect.save
          redirect_to admin_outreach_prospect_path(@prospect), notice: "Prospect added."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @prospect.update(prospect_params)
          redirect_to admin_outreach_prospect_path(@prospect), notice: "Prospect updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @prospect.destroy
        redirect_to admin_outreach_prospects_path, notice: "Prospect deleted."
      end

      def import_form
      end

      def import
        if params[:file].blank?
          redirect_to import_admin_outreach_prospects_path, alert: "Choose a CSV file to upload."
          return
        end

        @result = ::Outreach::ProspectImporter.new.import(params[:file].read, source: params[:source])
        flash.now[:notice] = "Imported #{@result.imported} prospects."
        render :import_form
      end

      private

      def set_prospect
        @prospect = ::Outreach::Prospect.find(params[:id])
      end

      def prospect_params
        params.require(:outreach_prospect).permit(:organization, :contact_name, :contact_title, :email, :phone, :website,
                                                  :sector, :city, :state, :source, :status, :notes)
      end
    end
  end
end
