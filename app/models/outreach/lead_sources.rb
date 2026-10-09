require "erb"

module Outreach
  # A curated guide to where organizations that need Swapper can be found,
  # plus ready-made searches for a sector and region.
  module LeadSources
    Source = Data.define(:name, :url, :category, :description)

    SOURCES = [
      # Government buyers
      Source.new("SAM.gov", "https://sam.gov/search/?index=opp", "Government buying",
                 "Federal contract opportunities. Search for HR software, workforce management, or employee transfer RFPs."),
      Source.new("USAspending.gov", "https://www.usaspending.gov/search", "Government buying",
                 "See which agencies already pay for HR/workforce software and who the vendors are."),
      Source.new("NASPO ValuePoint", "https://www.naspovaluepoint.org/", "Government buying",
                 "Cooperative contracts used by state governments. Getting on a contract here makes buying easy for every state."),
      Source.new("Sourcewell", "https://www.sourcewell-mn.gov/", "Government buying",
                 "Cooperative purchasing for cities, counties, schools and nonprofits. Vendors win contracts through its RFPs."),
      Source.new("BidNet Direct", "https://www.bidnetdirect.com/", "Government buying",
                 "Aggregates state and local bids. Set alerts for 'workforce management', 'HRIS' and 'transfer'."),
      Source.new("USA.gov agency index", "https://www.usa.gov/agency-index", "Government buying",
                 "Every federal agency with links to their sites, where HR and Human Capital offices are listed."),
      Source.new("Census of Governments", "https://www.census.gov/programs-surveys/cog.html", "Government buying",
                 "Downloadable lists of every county, city, township and special district in the U.S."),

      # Sector directories
      Source.new("NCES school district search", "https://nces.ed.gov/ccd/districtsearch/", "Directories",
                 "Every public school district with size and contact info. Large districts move teachers between schools constantly."),
      Source.new("CMS provider data (hospitals)", "https://data.cms.gov/provider-data/topics/hospitals", "Directories",
                 "Downloadable list of every U.S. hospital. Multi-hospital systems are prime targets (nurse transfers)."),
      Source.new("NACo county directory", "https://www.naco.org/counties", "Directories",
                 "National Association of Counties. Find county HR departments."),
      Source.new("Bureau of Prisons locations", "https://www.bop.gov/locations/", "Directories",
                 "Federal correctional facilities. Corrections officers and staff frequently request facility transfers."),
      Source.new("APTA member directory", "https://www.apta.com/", "Directories",
                 "American Public Transportation Association. Transit agencies with many depots and garages."),

      # Associations & events where HR buyers gather
      Source.new("IPMA-HR", "https://www.ipma-hr.org/", "Associations & events",
                 "Public-sector HR association. Conferences, chapter meetings and a vendor directory."),
      Source.new("NASPE", "https://www.naspe.net/", "Associations & events",
                 "National Association of State Personnel Executives: the HR directors of every state."),
      Source.new("SHRM", "https://www.shrm.org/", "Associations & events",
                 "The largest HR association. Local chapters are a cheap way to meet HR leaders in person."),
      Source.new("AASA", "https://www.aasa.org/", "Associations & events",
                 "School superintendents association. Superintendents and HR assistant superintendents decide on staffing tools."),
      Source.new("American Hospital Association", "https://www.aha.org/", "Associations & events",
                 "Hospital and health system leaders; see their workforce resources and events."),

      # Contact finding tools
      Source.new("LinkedIn Sales Navigator", "https://business.linkedin.com/sales-solutions/sales-navigator", "Finding contacts",
                 "Filter by title (HR Director, Chief People Officer, Workforce Manager), industry and region. Exports via CSV tools."),
      Source.new("Apollo.io", "https://www.apollo.io/", "Finding contacts",
                 "Contact database with a free tier. Export to CSV and import on the Prospects page."),
      Source.new("Hunter.io", "https://hunter.io/", "Finding contacts",
                 "Find and verify work emails for a domain (e.g. a county's .gov site). Verify before sending to protect your sender reputation.")
    ].freeze

    SECTOR_TERMS = {
      "Healthcare system" => [ "health system", "nurse" ],
      "Public school district" => [ "school district", "teacher" ],
      "State agency" => [ "state agency", "state employee" ],
      "County / city government" => [ "county government", "county employee" ],
      "Federal agency" => [ "federal agency", "federal employee" ],
      "Corrections / public safety" => [ "department of corrections", "correctional officer" ],
      "Transit / transportation" => [ "transit authority", "bus operator" ],
      "Retail / grocery chain" => [ "grocery chain", "store associate" ],
      "Bank / credit union" => [ "credit union", "branch" ],
      "Logistics / warehousing" => [ "distribution center", "warehouse associate" ],
      "Hospitality" => [ "hotel group", "hotel" ],
      "Staffing agency" => [ "staffing agency", "recruiter" ],
      "Other" => [ "multi-location employer", "employee" ]
    }.freeze

    def self.all = SOURCES

    def self.by_category = SOURCES.group_by(&:category)

    # Returns [label, url] pairs of web searches for the given sector/region.
    def self.searches(sector:, region: "")
      org, worker = SECTOR_TERMS.fetch(sector, SECTOR_TERMS["Other"])
      where = region.presence
      [
        [ "HR leaders at #{org.pluralize} on LinkedIn", google(%(site:linkedin.com/in ("HR Director" OR "Chief People Officer" OR "Human Resources Director") "#{org}" #{where}).squish) ],
        [ "#{org.capitalize} HR department pages", google(%("#{org}" "human resources" "transfer request" #{where}).squish) ],
        [ "Open RFPs for workforce / HR software", google(%(("request for proposal" OR RFP) ("workforce management" OR "HRIS" OR "employee transfer") #{org} #{where}).squish) ],
        [ "Union contracts with transfer rules", google(%("collective bargaining agreement" "#{worker}" "transfer" "seniority" #{where}).squish) ],
        [ "News: #{worker} shortages & transfers", google_news(%("#{worker}" (shortage OR transfer OR relocation) #{where}).squish) ]
      ]
    end

    def self.google(query) = "https://www.google.com/search?q=#{ERB::Util.url_encode(query)}"
    def self.google_news(query) = "https://news.google.com/search?q=#{ERB::Util.url_encode(query)}"
  end
end
