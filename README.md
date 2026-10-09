# Swapper

Swapper matches employees who want to trade work locations. Employees request a move, Swapper finds coworkers in
the same job who want to go the opposite way, and HR approves and completes the swaps in seniority order, with
email notifications and a full activity log.

## Who can do what

| Role | Access |
| --- | --- |
| **Employee** | Signs in by invitation, chooses a desired location, sees their request status. |
| **Manager** | Adds/imports/edits employees, runs matching, approves, rejects and completes swaps. |
| **HR Admin** | Everything above, plus locations, team invitations and roles, company settings, activity log. |
| **Platform owner** | `/admin`: every customer company, plus the sales outreach tool (lead finder, prospects, email templates, sending). |

Signing up always creates a **new** company workspace with the person as its HR Admin. Everyone else joins by
invitation, so nobody can get into a company's data by typing its name.

## How matching works

Two employees match when they're in the same company, each one's desired location is the other's current location,
and they have the same job title (case-insensitive). Same job code is labelled a stronger "job code" match. Matches
run automatically when employees are added, imported or change their request, and can be re-run from the Matches page.

Match lifecycle: `pending → approved → completed`, or `pending → rejected`.
Approving clears the other pending options for both people; completing swaps their current locations and closes both
requests. Rejected pairs aren't suggested again unless reopened.

## Running locally

Requires Ruby 3.3.

```sh
bundle install
bin/rails db:setup     # creates the database and loads demo data
bin/rails server
```

Open http://localhost:3000 and sign in with `admin@example.com`, `manager@example.com`, `employee@example.com` or
`owner@example.com` (password `password123`). In development, emails are written to the log instead of sent.

Run the tests with `bin/rails test`.

## Deploying

The app ships with a production `Dockerfile` and uses SQLite, so it runs on a single small server
(Render, Fly.io, Railway, a VPS with Kamal...). Requirements:

1. **A persistent volume mounted at `/rails/storage`**: the databases live there.
2. **Environment variables**: see `.env.example`. At minimum `SECRET_KEY_BASE`, `APP_HOST`, the `SMTP_*` settings,
   `MAIL_FROM` and `SOLID_QUEUE_IN_PUMA=1`.
3. **HTTPS**: production forces SSL; let your host terminate TLS in front of the app.
4. The container entrypoint runs `db:prepare` on boot, so migrations apply automatically.
5. Make yourself the platform owner once deployed:
   `bin/rails swapper:make_platform_admin EMAIL=you@yourdomain.com`
6. Load the starter outreach templates: `bin/rails db:seed` (demo data is only created in development).

Health check endpoint: `/up`.

## Outreach tool

See [docs/OUTREACH.md](docs/OUTREACH.md) for how the prospect finder and mailer work, the compliance rules it
enforces, and how to split it into its own repository later.

To start free, send through your Gmail account: the steps are in `.env.example`.

To have an AI agent research businesses, add prospects and send emails for you, see
[docs/outreach-agent/](docs/outreach-agent/README.md): it has the agent instructions, an OpenAPI spec and curl examples.
