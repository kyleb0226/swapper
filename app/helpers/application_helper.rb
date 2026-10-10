module ApplicationHelper
  STATUS_COLORS = {
    "pending" => "warning", "approved" => "primary", "completed" => "success", "rejected" => "secondary",
    "new" => "info", "contacted" => "primary", "replied" => "warning", "meeting" => "warning",
    "customer" => "success", "not_interested" => "secondary",
    "queued" => "info", "sent" => "success", "failed" => "danger", "skipped" => "secondary",
    "invited" => "warning", "active" => "success",
    "quoted" => "warning", "building" => "primary", "done" => "success", "declined" => "secondary"
  }.freeze

  def status_badge(status)
    tag.span(status.to_s.humanize, class: "badge text-bg-#{STATUS_COLORS.fetch(status.to_s, "light")}")
  end

  def nav_item(label, path, active: current_page?(path))
    tag.li(class: "nav-item") do
      link_to label, path, class: [ "nav-link", ("active" if active) ], aria: { current: ("page" if active) }
    end
  end

  # Column header link that toggles ascending/descending sort, keeping filters.
  def sort_link(label, column)
    active = @sort == column
    direction = active && @direction == "asc" ? "desc" : "asc"
    arrow = active ? (@direction == "asc" ? " ▲" : " ▼") : ""
    link_to "#{label}#{arrow}", request.query_parameters.merge(sort: column, direction: direction),
            class: "link-light text-decoration-none"
  end

  def page_title(title, subtitle = nil, &actions)
    content_for(:title, title)
    tag.div(class: "d-flex flex-wrap align-items-center justify-content-between gap-2 mb-4") do
      safe_join([
        tag.div { safe_join([ tag.h1(title, class: "h3 mb-0"), (tag.p(subtitle, class: "text-body-secondary mb-0") if subtitle) ].compact) },
        (tag.div(class: "d-flex flex-wrap gap-2", &actions) if actions)
      ].compact)
    end
  end

  def location_option_list(company)
    company.locations.ordered.map { |location| [ location.name, location.id ] }
  end
end
