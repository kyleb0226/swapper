# Outreach tool

The owner-only area under `/admin/outreach` is a small sales toolkit:

- **Find leads**: curated sources where organizations that need Swapper can be found (government purchasing portals,
  sector directories, HR associations, contact databases) plus a search builder that creates targeted Google/LinkedIn
  searches for a sector and region.
- **Prospects**: a simple CRM (organization, contact, sector, location, status pipeline, notes). Add by hand or import
  a CSV exported from Apollo, Sales Navigator, ZoomInfo, a vendor list or a spreadsheet.
- **Templates**: reusable emails with merge tags (`{{first_name}}`, `{{organization}}`, ...).
- **Send**: pick a template and prospects, preview, then send. Emails go out in the background, spaced 45 seconds apart.
- **Sent log**: every email with its status and any delivery error.
- **AI agent API**: a token-protected JSON API so an agent can do the research and data entry (and optionally the
  sending) for you. See [outreach-agent/](outreach-agent/README.md).

## Compliance built in (CAN-SPAM, and good practice for GDPR/CASL)

- Sending is disabled until `OUTREACH_POSTAL_ADDRESS` and a sender address are set.
- Every email includes your postal address and an unsubscribe link, plus `List-Unsubscribe` headers for one-click
  unsubscribe in Gmail/Outlook.
- Unsubscribed prospects are never emailed again, even if already queued.
- Nobody is emailed twice within 3 days, even if a batch is sent twice.
- A daily cap (`OUTREACH_DAILY_LIMIT`, default 50) protects your sending domain's reputation.

Tips: send from a separate domain or subdomain (e.g. `hello@getswapper.com`) with SPF, DKIM and DMARC set up, verify
addresses before importing, and keep emails short and personal. Cold email to government employees at their work
address is legal in the U.S. but many agencies route vendors to procurement; ask who the right person is.

## Extracting into its own app

The tool was written to be lifted out:

| Piece | Files |
| --- | --- |
| Models | `app/models/outreach.rb`, `app/models/outreach/*` |
| Mailer + job | `app/mailers/outreach/prospect_mailer.rb`, `app/jobs/outreach/delivery_job.rb`, `app/views/outreach/prospect_mailer/*` |
| Admin UI | `app/controllers/admin/outreach/*`, `app/views/admin/outreach/*` |
| Unsubscribe page | `app/controllers/outreach/unsubscribes_controller.rb`, `app/views/outreach/unsubscribes/*` |
| Tables | `db/migrate/*_create_outreach_tables.rb` (`outreach_*` tables only) |
| Agent API | `app/controllers/api/outreach/*`, `docs/outreach-agent/*` |
| Tests | `test/models/outreach_test.rb`, `test/controllers/outreach_flow_test.rb`, `test/controllers/outreach_api_test.rb` |

It depends on Swapper only for login (`Admin::BaseController` requires `User#platform_admin?`), the shared layout
helpers, and `ApplicationMailer`. In a new repo, copy those files, add a simple admin login, and replace the
Swapper-specific `Outreach::LeadSources` content and starter templates with ones for each product. To use one mailer
for several products, add a `product` column to prospects and templates.
