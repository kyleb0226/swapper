module Admin
  module Outreach
    class TemplatesController < BaseController
      before_action :set_template, only: %i[edit update destroy]

      def index
        @templates = ::Outreach::EmailTemplate.ordered
      end

      def new
        @template = ::Outreach::EmailTemplate.new
      end

      def create
        @template = ::Outreach::EmailTemplate.new(template_params)
        if @template.save
          redirect_to admin_outreach_templates_path, notice: "Template saved."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @template.update(template_params)
          redirect_to admin_outreach_templates_path, notice: "Template saved."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @template.destroy
        redirect_to admin_outreach_templates_path, notice: "Template deleted."
      end

      private

      def set_template
        @template = ::Outreach::EmailTemplate.find(params[:id])
      end

      def template_params
        params.require(:outreach_email_template).permit(:name, :subject, :body)
      end
    end
  end
end
