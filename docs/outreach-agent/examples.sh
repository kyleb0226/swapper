#!/usr/bin/env bash
# Example requests for the Swapper outreach API. Usage:
#   export SWAPPER_URL=http://localhost:3000      # or your deployed https:// address
#   export SWAPPER_TOKEN=<your OUTREACH_API_TOKEN>
#   bash docs/outreach-agent/examples.sh
set -euo pipefail

API="${SWAPPER_URL:?set SWAPPER_URL}/api/outreach"
AUTH="Authorization: Bearer ${SWAPPER_TOKEN:?set SWAPPER_TOKEN}"
JSON="Content-Type: application/json"

echo "== What am I allowed to do?"
curl -sS -H "$AUTH" "$API/status"; echo

echo "== Where to look for school districts in Ohio"
curl -sS -H "$AUTH" "$API/lead_sources?sector=Public%20school%20district&region=Ohio"; echo

echo "== Who is already on the list in Ohio?"
curl -sS -H "$AUTH" "$API/prospects?state=OH"; echo

echo "== Add (or update) a prospect"
curl -sS -X POST -H "$AUTH" -H "$JSON" "$API/prospects" -d '{
  "prospect": {
    "organization": "Example City Schools",
    "contact_name": "Jordan Lee",
    "contact_title": "Assistant Superintendent, Human Resources",
    "email": "jlee@example-schools.org",
    "website": "https://www.example-schools.org",
    "sector": "Public school district",
    "city": "Columbus",
    "state": "OH",
    "source": "https://www.example-schools.org/hr/staff-directory",
    "notes": "42 schools. Annual teacher transfer window each spring per their union contract."
  }
}'; echo

echo "== Add a note to prospect 1"
curl -sS -X PATCH -H "$AUTH" -H "$JSON" "$API/prospects/1" -d '{"prospect": {"notes": "Posted an HR software RFP in March."}}'; echo

echo "== Templates"
curl -sS -H "$AUTH" "$API/templates"; echo

echo "== Send template 1 to prospects 1 and 2 (needs OUTREACH_API_ALLOW_SEND=1)"
curl -sS -X POST -H "$AUTH" -H "$JSON" "$API/campaigns" -d '{"template_id": 1, "prospect_ids": [1, 2]}'; echo

echo "== Recent emails"
curl -sS -H "$AUTH" "$API/emails?limit=20"; echo
