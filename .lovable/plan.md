# Specialized AI SaaS Refactor

Replaces the generic admin template with the blueprint: modular automation pages, a 10-task receptionist configurator, automatic script regeneration, OpenRouter failover, usage metering and Google integrations.

## 1. Separate pages for each automation
- Client dashboard: each purchased automation gets its own page (Voice Receptionist, Web Chatbot, Lead Qualifier, Scheduler). An automation the client hasn't bought shows as locked with a "Get this automation" card.
- Voice Receptionist page: animated voice orb customizer (3D/2D style, color, size, live preview), call transcripts with an audio player, and Google Calendar/Sheets connection cards.
- Admin: the generic Automations table becomes a list that opens a matching per-automation page with the same controls, plus admin-only overrides.

## 2. 10-task receptionist configurator (admin and client)
The toggle matrix covers Voice & Text Mode (orb customizer), Appointment Booking, Knowledge Base, Mid-Chat SMS, Lead Qualification, Quote Estimator, Staff Escalation, Auto Translation, Intake Forms and Post-Chat Survey. Each task has its own settings (for example, quote price rules or escalation contacts). The chat engine builds its AI tool list only from the tasks that are switched on. A "Tool schema preview" panel shows the result.

## 3. Script lock and automatic regeneration
- Clients can only reveal, hide and copy their script. There is no regenerate button.
- When a client changes their domain, webhook URL or signing key, the system:
  1. queues a re-crawl
  2. creates a new script token and snippet
  3. sets "reinstallation required", which shows a dashboard alert until the client confirms they updated their site
- The admin keeps a manual "Force regenerate" override. Every regeneration is written to the audit log.

## 4. OpenRouter key rotation and model fallback
- Admin Infrastructure page: an OpenRouter key pool (add, enable, set cooldown, see request and error counts) alongside the Groq pool.
- When a key gets a 429 or 5xx error, the engine moves to the next key. When every key fails for a model, it moves down the model chain: llama-3.3-70b → qwen-2.5-72b → nemotron-3-ultra → gemma-2-9b.
- Each automation type can have its own model chain, edited in a "Model routing" panel.
- This needs your OpenRouter API keys. I'll request them securely during the build.

## 5. Usage metering and overages
- Each plan gets hard caps (for example, 300 call minutes or 500 SMS) and an overage rate ($0.20 per extra unit).
- Call minutes, SMS and tokens are tracked per client per billing period. Usage over the cap is flagged and totaled.
- Clients see usage meters. Admins see an Overages ledger.

## 6. Google Calendar and Sheets
Per-client connection cards with connected/disconnected status. New bookings go to the client's calendar and new leads go to their sheet. This uses each client's own Google account, which requires a Google sign-in setup that a workspace admin configures once.

## 7. Backend flow testing
I'll run each flow against the live database and fix anything that breaks:
- Tenant isolation: client A cannot read client B's leads or transcripts
- Payment approval: approving a payment activates the automation and extends its expiry
- Transcript logging from the widget
- Subscription expiry: warning, grace period, then suspension

The sticky top bar is already done; I'll check it again on mobile.

## Technical details
- New tables: `automation_tasks` (automation_id, task_key, enabled, config jsonb), `openrouter_keys`, `model_routes` (automation_slug, ordered models), `usage_meters` (automation_id, period, call_minutes, sms_count, tokens), `plan_limits` (slug, minute_cap, sms_cap, overage_rate), `integration_connections` (automation_id, provider, status), `crawl_jobs`.
- New columns on `automation_instances`: `requires_reinstallation`, `orb_settings` jsonb, `hmac_key`, `script_snippet`.
- A BEFORE UPDATE trigger on `automation_instances` detects changes to domain, webhook or HMAC fields, rotates `script_token`, sets `requires_reinstallation`, inserts a `crawl_jobs` row and writes to the audit log. Clients cannot write `script_token` or `client_id`; a column guard trigger enforces this.
- `src/lib/llm-router.server.ts`: key round-robin with cooldowns and the model chain. It is used by the widget chat route.
- Tool schema compiler: `src/lib/receptionist-tasks.ts` maps enabled tasks to function-tool definitions.
- Every new table gets grants and row-level security, scoped through `owns_automation()` for clients and `is_admin()` for staff.
