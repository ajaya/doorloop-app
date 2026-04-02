# CLAUDE.md — doorloop-app

## What This Is
Ruby MCP server for DoorLoop property management via headless Chrome (Playwright).
Exposes 9 MCP tools to AI assistants (Claude, etc.) to read and interact with DoorLoop.

Target account: `https://bansals.app.doorloop.com`

---

## Build & Test

```bash
bundle install
bundle exec rake test                        # Run full suite
bundle exec ruby -Itest test/path_test.rb    # Single file
bundle exec ruby -Itest test/path_test.rb -n test_method_name  # Single test
bin/doorloop console                         # IRB with DoorLoopApp loaded
bin/doorloop server                          # Start MCP server (stdio)
bin/doorloop server --http                   # Start MCP server (HTTP on port 9293)
bin/doorloop server --http --port 8080       # Custom HTTP port
DOORLOOP_HEADLESS=false bin/doorloop console # Visible browser
```

Tests use Minitest + Mocha. No live DoorLoop connection needed — all browser calls mocked.

---

## Docker

- `Dockerfile` — 4-stage build: `base` → `gems` → `playwright` → `app`
- `docker-compose.yml` — two services: `mcp` (stdio server) and `login` (one-shot auth)
- Base image: `ruby:4.0.1-slim-bookworm` + Node.js 22 + Chromium via `playwright install --with-deps`
- `/data` volume maps to `~/.doorloop-mcp` on host (Chrome profile + SQLite)
- Required Chromium flags in container: `PLAYWRIGHT_CHROMIUM_ARGS=--no-sandbox --disable-setuid-sandbox`
- `mcp` service: `stdin_open: true`, `tty: false` (stdio transport requires open stdin, no TTY)
- `login` service: `stdin_open: true`, `tty: true` (interactive)

```bash
docker compose build
docker compose run --rm login    # one-time auth, saves Chrome session
docker compose run --rm mcp      # start MCP stdio server
```

---

## Architecture

### Entry Points
- `bin/doorloop` — Thor CLI: `server`, `login`, `console`, `version`
- All CLI output goes to **stderr**; stdout is reserved for MCP JSON-RPC

### Layers (top to bottom)
```
MCP Tools (lib/doorloop_app/tools/)
  ↓
Data::Executor (lib/doorloop_app/data/executor.rb)
  Layer 1: Api::Endpoints/* — direct HTTP (requires discovered registry token)
  Layer 2: Browser::Pages/* — Playwright API interception
  Layer 3: Vision::Client — Claude AI text extraction (fallback)
  ↓ (on success)
Store → Models (SQLite via Sequel ORM)
```

### Key Singletons (lib/doorloop_app.rb)
```ruby
DoorLoopApp.session      # Browser::Session (Playwright)
DoorLoopApp.store        # Store → SQLite models
DoorLoopApp.executor     # Data::Executor (3-layer)
DoorLoopApp.configuration
DoorLoopApp.eager_load!  # Zeitwerk eager load (called by entry points)
```

### MCP Transport

`Server.run` supports two transports: **stdio** (default, JSON-RPC over stdin/stdout) and **HTTP** (`--http` flag, StreamableHTTPTransport via Rack/WEBrick on `/mcp`, default port 9293).

---

## MCP Tools (9 implemented)

| Tool | Class | Notes |
|------|-------|-------|
| `doorloop_login` | `LoginTool` | Returns `two_factor_required` status if 2FA needed |
| `doorloop_submit_2fa` | `Submit2faTool` | Submits 6-digit code |
| `doorloop_list_properties` | `ListPropertiesTool` | Cached; refetches if stale (>5min) |
| `doorloop_list_units` | `ListUnitsTool` | Fetches per-property; falls back to /units |
| `doorloop_list_tenants` | `ListTenantsTool` | All tenants; cached |
| `doorloop_list_leases` | `ListLeasesTool` | All active leases (API ignores property filter) |
| `doorloop_find_tenant` | `FindTenantTool` | DB search → LLM fuzzy match fallback |
| `doorloop_receive_payment` | `ReceivePaymentTool` | Fills form, does **NOT** submit |
| `doorloop_list_lease_transactions` | `ListLeaseTransactionsTool` | Requires `lease_id`; browser-only (no API layer) |

---

## Browser Pages (API Interception Pattern)

All list pages use `page.expect_response` to capture the XHR API response during navigation.
No DOM scraping on list pages — returns `[]` on failure.

```ruby
response = page.expect_response(
  ->(resp) { resp.url.include?(API_PATH) && resp.status == 200 },
  timeout: 15_000
) { navigate_to(PATH) }
api_body = JSON.parse(response.body)
```

### DoorLoop API Endpoints (discovered)
- Properties: `GET /api/properties/custom-fields`
- Units: `GET /api/units/leases/custom-fields`
- Tenants: `GET /api/leases/tenants/` (with `custom-fields`, excludes `widgets`)
- Leases: `GET /api/leases/` (with `filter_status`)

### Payment Form Selectors (data-cy)
- Tenant autocomplete: `[data-cy="AutoCompleteInput-receivedFromTenant"]`
- Date: `#date-pickerchargeDueDate`
- Amount: `[data-cy="amountReceived"] input`
- Payment method: `[data-cy="AutoCompleteInput-paymentMethod"]`
- Memo: `[data-cy="DLUI-Dialog-MemoTextArea"]`
- Save: `[data-cy="Action-Button-Save"]` (user clicks this manually)

### Payment URL Pattern
`/leases/active-leases/{lease_id}/transactions/payment/new?period=all-time&filter_lease={lease_id}`

### Transactions XHR Capture Gotcha
After a payment is saved, DoorLoop auto-redirects to the transactions page. Navigating to the same URL again won't re-fire the XHR (React Router skips the reload). `LeaseTransactionsPage#list_all` detects this and navigates to `/leases/active-leases` first to force a fresh XHR on the subsequent navigation. URL matcher requires both `/api/transactions` and `filter_lease` query param to avoid matching unrelated API calls.

---

## Models (Sequel::Model + SQLite)

All models follow the `JsonBacked` pattern:
- `data` column stores full API JSON (source of truth)
- Indexed columns extracted for querying (`name`, `property_id`, etc.)
- `upsert_all(items)` — insert or update by id
- `to_api` — parses `data` JSON, adds `_stored_at` timestamp
- `find_by_name(str)` — case-insensitive LIKE
- `stale?(max_age: 300)` — true if no records updated in last N seconds
- `setup!(db)` — creates table + binds dataset (called from Store)

### Tables
| Model | TABLE | ID_FIELD | Notable COLUMNS |
|-------|-------|----------|-----------------|
| Property | `:properties` | `"id"` | name, address, property_type, units_count |
| Unit | `:units` | `"unitId"` | name, property_id (`"property"`), status (`"leaseStatus"`), rent (`"marketRent"`) |
| Lease | `:leases` | `"id"` | name, property_id, unit_ids (JSON array), status, start_date, end_date, total_rent, balance |
| Tenant | `:tenants` | `"id"` | name, first_name, last_name, email, phone, property_id, lease_id, unit_ids, status, balance_due |
| LeaseTransaction | `:lease_transactions` | `"id"` | lease_id, property_id, txn_type (`"type"`), amount, date, description, status |

**Important**: `Sequel::Model.require_valid_table = false` is set in `lib/doorloop_app.rb` so models
can be autoloaded by Zeitwerk before `setup!(db)` is called.

### DB Path
Default: `~/.doorloop-mcp/doorloop.sqlite3`

---

## Notifications

`lib/doorloop_app/notifications/payment_confirmation.rb` — sends email after payment is confirmed via CLI.

- Triggered by `bin/doorloop payment receive` after user clicks Save and presses Enter
- Uses `AgentMail::Client` (same AgentMail integration as 2FA — no separate SMTP config)
- Fetches latest transactions for the lease, matches by amount, emails a summary
- `Notifications::PaymentConfirmation.send!(transactions:, tenant_name:, config:)`
- Only fires if `config.email_notifications_configured?` (requires `AGENTMAIL_API_KEY` + `AGENTMAIL_INBOX_ID` + `DOORLOOP_CONFIRMATION_EMAIL_TO`)

---

## CLI Subcommands

`bin/doorloop` exposes top-level commands and subcommand groups:

| Command | Description |
|---------|-------------|
| `version` | Print version |
| `server` | Start MCP stdio server |
| `login` | Interactive login (saves Chrome session) |
| `console` | IRB with DoorLoopApp singletons loaded |
| `properties list` | List all properties |
| `units list` | List units (optionally filtered) |
| `tenants list` | List all tenants |
| `tenants find QUERY` | DB search + LLM fallback |
| `leases list` | List all leases |
| `leases transactions` | Fetch transactions for a tenant's lease (browser required) |
| `payment receive` | Fill payment form + optional email confirmation |

`leases transactions` options: `--tenant/-t`, `--lease-id/-l`, `--raw/-r`
- Tenant lookup: DB → refresh → LLM fuzzy match (same 3-layer as payment)

`payment receive` options: `--tenant/-t`, `--amount/-a` (required), `--lease-id/-l`, `--date/-d`, `--method/-m` (default: EFT), `--memo`, `--raw/-r`
- `--date` accepts: `YYYY-MM-DD`, `today`, `yesterday`, or `MM/DD/YYYY`
- `--raw`: form state printed to **stderr** as JSON; confirmed transactions printed to **stdout** as JSON — keeps stdout clean for piping
- Without `--raw`: all output to stdout as human-readable text; progress/errors to stderr

---

## Tenant Matching (LLM Fallback)

`lib/doorloop_app/llm/tenant_matcher.rb` — used by `PaymentPage#find_tenant` when DB search fails.

- Model: `claude-haiku-4-5-20251001` (default), overridable via `DOORLOOP_LLM_MODEL`
- Uses `ruby_llm` gem → `RubyLLM.chat(model:).ask(prompt)`
- Requires `ANTHROPIC_API_KEY` in `.env.local`
- Private `call_llm(prompt)` method is stubbed in tests

---

## Authentication

- Login URL: `https://app.doorloop.com/auth/login` (redirects to bansals.app.doorloop.com)
- Login selectors: `#email`, `#password`, `[data-cy="signIn"]`
- 2FA: single OTP input, filled character by character via JS
- AgentMail integration: auto-retrieves 2FA code from email (`AGENTMAIL_API_KEY`, `AGENTMAIL_INBOX_ID`)
- Session check: looks for `/login`, `/signin`, `/auth` in URL path
- Chrome profile persisted at `~/.doorloop-mcp/chrome-profile/`

---

## Zeitwerk Inflections
```ruby
loader.inflector.inflect("mcp" => "MCP", "cli" => "CLI", "llm" => "LLM")
```

---

## Code Conventions

- `# frozen_string_literal: true` on every Ruby file
- `$stderr.puts` for all logging (stdout reserved for MCP JSON-RPC)
- `log "..."` helper in page objects (writes to stderr)
- MCP tool response: `::MCP::Tool::Response.new([{type: "text", text: ...}], error: true/false)`
- Test mock builders in `test/test_helper.rb`: `build_mock_session`, `build_mock_page`, `build_server_context`
- Playwright `TimeoutError` constructor: `new(message: "...")` (keyword arg required)

---

## Environment Variables (.env.local)

```bash
DOORLOOP_EMAIL=...                        # required
DOORLOOP_PASSWORD=...                     # required
DOORLOOP_URL=bansals.app.doorloop.com
DOORLOOP_HEADLESS=true                    # false to see browser
DOORLOOP_PROFILE_DIR=~/.doorloop-mcp/chrome-profile
DOORLOOP_DB_PATH=~/.doorloop-mcp/doorloop.sqlite3
DOORLOOP_API_REGISTRY=config/api_registry.json  # optional, path to API token registry

# AgentMail (auto 2FA + payment confirmation emails)
AGENTMAIL_API_KEY=...
AGENTMAIL_INBOX_ID=...

# Claude AI (tenant matching + vision fallback)
ANTHROPIC_API_KEY=...
DOORLOOP_LLM_MODEL=claude-haiku-4-5-20251001     # for tenant fuzzy matching
DOORLOOP_VISION_MODEL=claude-sonnet-4-20250514   # for vision page extraction

# Payment confirmation email recipient (requires AgentMail above)
DOORLOOP_CONFIRMATION_EMAIL_TO=...
```

---

## Known Gotchas

- `playwright-ruby-client` has a binary stdout bug — patched via `playwright_transport_patch.rb` (force_encoding UTF-8)
- CloudFront blocks headless Chrome — use `DOORLOOP_HEADLESS=false` for browser discovery scripts
- `has_valid_session?` checks both URL path and page title (error pages can redirect to non-login URLs)
- DoorLoop leases API returns **all** leases regardless of `filter_property` param — always fetch once
- AgentMail message IDs may contain special chars — URL-encode with `CGI.escape`
- AgentMail responses wrap data in `.body` — always call `.body` on API responses
