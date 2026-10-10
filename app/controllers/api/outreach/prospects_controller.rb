module Api
  module Outreach
    class ProspectsController < BaseController
      FIELDS = %i[organization contact_name contact_title email phone website sector city state source status notes].freeze

      def index
        scope = ::Outreach::Prospect.ordered
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(sector: params[:sector]) if params[:sector].present?
        scope = scope.where(state: params[:state]) if params[:state].present?
        if params[:q].present?
          scope = scope.where("organization LIKE :q OR contact_name LIKE :q OR email LIKE :q",
                              q: "%#{::Outreach::Prospect.sanitize_sql_like(params[:q])}%")
        end
        render json: { prospects: scope.limit(params.fetch(:limit, 200).to_i.clamp(1, 1000)).map { |p| prospect_json(p) } }
      end

      def show
        prospect = ::Outreach::Prospect.find(params[:id])
        render json: prospect_json(prospect).merge(
          "emails" => prospect.emails.recent.map { |e| e.as_json(only: %i[id subject status sent_at created_at]) }
        )
      end

      # Creates a prospect, or updates the existing one with the same email
      # (so an agent re-finding a contact doesn't create duplicates). The
      # response's can_email / blocked_reason say whether a first email may go out.
      def create
        attrs = params.require(:prospect).permit(*FIELDS)
        prospect = attrs[:email].present? && ::Outreach::Prospect.find_by(email: attrs[:email].to_s.strip.downcase)
        created = prospect.blank?
        prospect ||= ::Outreach::Prospect.new(source: "AI agent")
        # Never let an agent reset someone who unsubscribed or already declined.
        attrs = attrs.except(:status) unless created
        prospect.assign_attributes(attrs.to_h.compact_blank)

        if prospect.save
          render json: prospect_json(prospect).merge("created" => created), status: created ? :created : :ok
        else
          render json: { errors: prospect.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        prospect = ::Outreach::Prospect.find(params[:id])
        if prospect.update(params.require(:prospect).permit(*FIELDS))
          render json: prospect_json(prospect)
        else
          render json: { errors: prospect.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end
end
