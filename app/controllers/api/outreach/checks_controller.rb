module Api
  module Outreach
    # Lets an agent ask "may I contact this person / this organization?" before
    # spending time researching them.
    #   GET /api/outreach/check?email=jane@county.gov&organization=Example County
    class ChecksController < BaseController
      def show
        email = params[:email].to_s.strip.downcase.presence
        organization = params[:organization].to_s.strip.presence
        domain = params[:domain].presence && ::Outreach::Suppression.clean_domain(params[:domain])
        if email.nil? && organization.nil? && domain.nil?
          render json: { error: "Pass email, organization and/or domain" }, status: :bad_request
          return
        end

        prospect = (email && ::Outreach::Prospect.find_by(email: email)) ||
                   ::Outreach::Prospect.new(email: email, organization: organization || domain || "unknown")
        prospect.organization = organization if organization && prospect.new_record?
        reason = ::Outreach::ContactPolicy.new.blocked_reason(prospect) unless email.nil?
        reason ||= organization_reason(organization, domain)

        render json: {
          can_contact: reason.nil?,
          reason: reason,
          existing_prospect_id: prospect.persisted? ? prospect.id : nil,
          organization_contacts: organization_prospects(organization, domain || ::Outreach::ContactPolicy.org_domain(email))
        }
      end

      private

      def organization_reason(organization, domain)
        return "#{domain} is on the do-not-contact list" if domain && ::Outreach::Suppression.exists?(domain: domain)

        probe = ::Outreach::Prospect.new(email: "probe@#{domain || "invalid.example"}", organization: organization || "")
        reason = ::Outreach::ContactPolicy.new.colleague_contacted(probe, [])
        "someone at this organization (#{reason}) was already contacted" if reason
      end

      def organization_prospects(organization, domain)
        key = ::Outreach::ContactPolicy.org_key(organization)
        scope = ::Outreach::Prospect.all
        matches = []
        matches += scope.where("email LIKE ?", "%@#{::Outreach::Prospect.sanitize_sql_like(domain)}").to_a if domain
        matches += scope.select { |p| ::Outreach::ContactPolicy.org_key(p.organization) == key }.to_a if key
        matches.uniq.first(20).map { |p| p.as_json(only: %i[id organization contact_name contact_title email status]) }
      end
    end
  end
end
