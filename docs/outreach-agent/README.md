# Connecting an AI agent to the outreach tool

Swapper has a small JSON API that lets an AI agent (Claude, ChatGPT, or any agent framework that can make HTTP
requests) do your prospecting: research organizations on the web, add the right contacts to your prospect list,
and, if you allow it, send your outreach emails.

## Files in this folder

| File | What it's for |
| --- | --- |
| `AGENT_PROMPT.md` | Instructions to paste into the agent (its "system prompt" / custom instructions). |
| `openapi.yaml` | Machine-readable description of the API. Import it as "actions"/"tools" in agent builders that support OpenAPI (e.g. ChatGPT custom GPT Actions). |
| `examples.sh` | Copy-paste `curl` commands for every endpoint, handy for testing and for agents that run shell commands (e.g. Claude Code). |

## Setup

1. **Turn on the API.** Generate a token with `bin/rails secret` and set it as `OUTREACH_API_TOKEN` (see
   `.env.example`). Without a token the API is completely off.
2. **Decide whether the agent may send.** Leave `OUTREACH_API_ALLOW_SEND=0` to start: the agent finds and adds
   prospects, and you review them and send from `/admin/outreach` yourself. Set it to `1` once you trust it.
3. **Set up email** (the Gmail settings in `.env.example` are free) and `OUTREACH_POSTAL_ADDRESS`.
4. **Give the agent access:**
   - **Agent on your own computer** (e.g. Claude Code): run the app locally and point it at `http://localhost:3000`.
   - **Hosted agent** (ChatGPT, a cloud agent): the app must be deployed so it has a public `https://` address.
5. **Paste `AGENT_PROMPT.md`** into the agent, filling in your app URL and token where it says to (store the token as
   a secret/credential if the tool supports that, rather than in plain text).
6. **Start small.** Ask it for "10 prospects: mid-size hospital systems in Ohio" and check the results at
   `/admin/outreach/prospects` before scaling up.

## Safety rules the app enforces (no matter what the agent does)

- The token is the only way in; nothing else in the app is reachable through it.
- Sending only works when `OUTREACH_API_ALLOW_SEND=1` and your postal address and sender are configured.
- Daily limit (`OUTREACH_DAILY_LIMIT`), never emailing anyone who unsubscribed, and never emailing the same prospect
  twice within 3 days.
- Re-adding a prospect updates the existing record instead of duplicating it, and an agent can't reset someone
  marked "not interested" or "customer" back to "new".
- Every email has your postal address and an unsubscribe link, and shows up in `/admin/outreach/emails`.

If the token ever leaks, change `OUTREACH_API_TOKEN` and restart the app; the old token stops working immediately.
