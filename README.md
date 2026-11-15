# doorloop-app

An MCP (Model Context Protocol) server for [DoorLoop](https://www.doorloop.com/) property management. Allows AI assistants (Claude, etc.) to interact with DoorLoop through local agent-browser automation and authenticated API calls inside Chrome.

## Features

### MCP Tools

| Tool | Description |
|------|-------------|
| `doorloop_login` | Authenticate with DoorLoop. Returns 2FA status if required. |
| `doorloop_submit_2fa` | Submit a 2FA verification code. |
| `doorloop_list_properties` | List all properties with address, type, and unit count. |
| `doorloop_list_units` | List units for a property with status and rent. |
| `doorloop_list_tenants` | List all tenants with contact info, lease, and balance. |
| `doorloop_find_tenant` | Search for a tenant by name or email. Falls back to AI fuzzy matching. |
| `doorloop_list_leases` | List leases, optionally filtered by property or status. |
| `doorloop_receive_payment` | Fill a payment form for a tenant (does **not** submit — user reviews and clicks Save). |
| `doorloop_list_lease_transactions` | List all transactions for a specific lease (requires `lease_id`). |

### Data Retrieval Strategy

Each read operation uses a 3-layer fallback:

1. **Browser API replay** — Calls discovered DoorLoop endpoints using `fetch` inside authenticated Chrome, with its HTTP-only cookies and observed authorization/CSRF headers.
2. **Network discovery** — Navigates the relevant page with agent-browser, captures the actual API response and remembers the route for future API replay. Full records and IDs are preserved.
3. **Optional paid AI** — Disabled by default. Existing Claude text extraction and fuzzy matching require both `DOORLOOP_ALLOW_PAID_AI=true` and an Anthropic API key.

Browser automation runs locally, uses the free Apache-2.0 agent-browser CLI, and requires no cloud-browser account or LLM subscription. Login/2FA and payment-form preparation still use browser controls. Payment submission remains a manual Save action.

All fetched data is cached in a local SQLite database (`~/.doorloop-mcp/doorloop.sqlite3`).

## Requirements

- Ruby 4.0.9 (see `.ruby-version`)
- Node.js 22+ (for the agent-browser npm launcher)
- Local Chrome/Chromium, or the free browser downloaded by `agent-browser install`
- A DoorLoop account

## Setup

```bash
# Install dependencies
bundle install
npm ci
npx --no-install agent-browser install

# Configure environment
cp .env.example .env.local
# Set DOORLOOP_URL if needed. Saved email/password are optional for manual login.

# Authenticate once in visible local Chrome, including 2FA
bundle exec bin/doorloop login --manual

# Reuse that profile for browser API requests
bundle exec bin/doorloop properties list --refresh
```


### Persistent authentication and browser API access

Session-only cookies and tab session storage are also saved/restored by agent-browser using its stable `--restore` key. Saved state is encrypted with a per-profile key (`doorloop-state.key`, mode 0600); keep that key with the profile. Docker persists the native restore files in the same `/data` volume.

The default profile remains `~/.doorloop-mcp/chrome-profile`, so an existing profile is reused in place. A successful `login --manual` closes Chrome cleanly, keeping cookies, local storage and trusted-device state for later CLI/MCP processes. Select DoorLoop's “Don't ask again” option during 2FA when available. DoorLoop can still expire/revoke a session or require 2FA again; the app reports this instead of claiming the session is authenticated.

`DOORLOOP_PROFILE_DIR` selects a different persistent profile. `DOORLOOP_BROWSER_EXECUTABLE` selects an installed browser. `DOORLOOP_AGENT_BROWSER_PATH` selects a globally installed CLI when the project-local npm binary is unavailable. Keep using the same profile and OS account; Chrome profiles should not be open in another Chrome process or copied between operating systems.

Routes are saved at `~/.doorloop-mcp/api_registry.json` (override with `DOORLOOP_API_REGISTRY`). The registry stores paths, read methods, query parameters and JSON search filters, with no authentication headers. The old `api_token.json` is no longer read or written.

Programmatic API calls run in the browser, with same-origin checks and redirects disabled:

```ruby
client = DoorLoopApp::Api::Client.new(session: DoorLoopApp.session)
client.get("/api/properties/custom-fields", params: { page: 1 })
# client.post("/api/<verified-endpoint>", body: verified_payload)
# Writes are not retried automatically. Verify endpoint and payload first.
```

For network inspection in `bin/doorloop console`:

```ruby
session = DoorLoopApp.session
session.ensure_authenticated!
requests = session.browser.command("network", "requests")
# Inspect the full request/response, including its body, using an observed ID:
# session.browser.command("network", "request", request_id)
```

### Environment Variables

```bash
DOORLOOP_EMAIL=you@example.com
DOORLOOP_PASSWORD=yourpassword
DOORLOOP_URL=https://yourorg.app.doorloop.com   # defaults to bansals.app.doorloop.com

# Optional
DOORLOOP_HEADLESS=true                  # set false to see the browser

# AgentMail — automatic 2FA retrieval + payment confirmation emails
AGENTMAIL_API_KEY=...
AGENTMAIL_INBOX_ID=...
DOORLOOP_CONFIRMATION_EMAIL_TO=you@example.com  # enables post-payment email

# Optional paid Claude AI — disabled by default
DOORLOOP_ALLOW_PAID_AI=false
ANTHROPIC_API_KEY=...
DOORLOOP_LLM_MODEL=claude-haiku-4-5-20251001    # model for tenant fuzzy matching
DOORLOOP_VISION_MODEL=claude-sonnet-4-20250514  # model for vision page extraction
```

## Docker

### Quick start

```bash
# Build the image
docker compose build

# Login once to persist the Chrome session
docker compose run --rm login

# Run as MCP server (used by Claude Desktop / MCP clients)
docker compose run --rm mcp
```

The image bundles Ruby 4.0.9, Node.js 22, Debian Chromium, and agent-browser. Data (Chrome profile + SQLite DB) is persisted to `~/.doorloop-mcp` on the host via a volume mount.

### MCP client config (Docker)

```json
{
  "mcpServers": {
    "doorloop": {
      "command": "docker",
      "args": ["compose", "-f", "/path/to/doorloop-app/docker-compose.yml", "run", "--rm", "mcp"]
    }
  }
}
```

### Image details

| Stage | Base | Purpose |
|-------|------|---------|
| `base` | `ruby:4.0.9-slim-bookworm` | Ruby + Node.js 22 + build deps |
| `gems` | `base` | Bundle install (without development group) |
| `browser` | `gems` | `npm ci` + local agent-browser executable |
| `app` | `browser` | Full source + `/data` volume |

- `ENTRYPOINT`: `bundle exec bin/doorloop`
- `CMD`: `server`
- Chromium runs headless with `--no-sandbox --disable-setuid-sandbox` (required in containers)
- `/data` volume: Chrome profile at `/data/chrome-profile`, SQLite at `/data/doorloop.sqlite3`

---

## Usage

### As an MCP Server (for Claude Desktop / Claude Code)

```bash
bin/doorloop server
```

Add to your MCP config:
```json
{
  "mcpServers": {
    "doorloop": {
      "command": "/path/to/doorloop-app/bin/doorloop",
      "args": ["server"]
    }
  }
}
```

### CLI Commands

```bash
bin/doorloop version              # Print version
bin/doorloop server               # Start MCP stdio server
bin/doorloop login                # Interactive login
bin/doorloop console              # IRB/Pry console with DoorLoopApp loaded
bin/doorloop properties list      # List all properties
bin/doorloop units list           # List units
bin/doorloop tenants list         # List all tenants
bin/doorloop leases list          # List all leases
bin/doorloop leases transactions --tenant "Shital"        # Fetch transactions by tenant name
bin/doorloop leases transactions --lease-id abc123 --raw  # JSON output
bin/doorloop payment receive \
  --tenant "Prayag Bansal" \
  --amount 4500 \
  --date 2026-03-01 \
  --method EFT \
  --memo "March rent"             # Fill payment form (prompts to confirm after Save)
```

### Console Usage

```ruby
# Load and authenticate
session = DoorLoopApp.session
session.start
session.ensure_authenticated!

# Fetch and cache data
DoorLoopApp.executor.call(:list_properties)
DoorLoopApp.executor.call(:list_tenants)
DoorLoopApp.executor.call(:list_leases)

# Query cached data
store = DoorLoopApp.store
store.all_tenants
store.find_tenant_by_name("Prayag")
store.active_leases

# Fill a payment form (does not submit)
payment_page = DoorLoopApp::Browser::Pages::PaymentPage.new(session)
payment_page.fill_payment(
  tenant_name: "Prayag Bansal",
  amount: "1200",
  date: "2026-03-01",
  payment_method: "EFT",
  memo: "March rent"
)
```

## Architecture

### System Overview

```mermaid
graph TD
    subgraph Clients["Clients"]
        AI["AI Assistant\n(Claude, etc.)"]
        CLI["bin/doorloop\nCLI"]
    end

    subgraph MCP["MCP Layer"]
        SERVER["MCP Server\n(stdio transport)"]
        TOOLS["9 MCP Tools\nlogin · list_properties · list_units\nlist_tenants · list_leases · find_tenant\nreceive_payment · list_lease_transactions\nsubmit_2fa"]
    end

    subgraph Executor["Data::Executor (3-layer fallback)"]
        L1["Layer 1: Browser API\nauthenticated fetch"]
        L2["Layer 2: Discovery\nagent-browser network capture"]
        L3["Layer 3: Vision\nClaude AI text extraction"]
    end

    subgraph External["External"]
        DL["DoorLoop\nbansals.app.doorloop.com"]
        AM["AgentMail\n2FA + email"]
        CLAUDE_AI["Claude AI\ntenant matching · vision"]
    end

    subgraph Storage["Storage"]
        DB["SQLite\n~/.doorloop-mcp/doorloop.sqlite3"]
        CHROME["Chrome Profile\npersistent session"]
    end

    AI -->|"MCP JSON-RPC\n(stdio)"| SERVER
    CLI --> TOOLS
    SERVER --> TOOLS
    TOOLS --> Executor
    L1 -->|"REST"| DL
    L2 -->|"agent-browser"| DL
    L3 --> CLAUDE_AI
    Executor --> DB
    L2 --> CHROME
    AM -->|"OTP codes"| L2
    AM -->|"confirmation\nemail"| CLI
```

### Data Retrieval Flow

```mermaid
flowchart LR
    REQ["operation\ncall"] --> API

    API{"Layer 1\nBrowser API\nroute known?"}
    API -->|yes| API_CALL["HTTP GET\n/api/..."]
    API_CALL -->|success| STORE
    API_CALL -->|fail / auth error| BROWSER

    API -->|unknown route| BROWSER

    BROWSER{"Layer 2\nBrowser\nXHR intercept"}
    BROWSER --> NAV["navigate_to(path)\n+ expect_response(...)"]
    NAV -->|success| STORE
    NAV -->|timeout / error| VISION

    VISION{"Layer 3\nVision\nANTHROPIC_API_KEY?"}
    VISION -->|configured| EXTRACT["Claude reads\npage text"]
    EXTRACT -->|success| STORE
    EXTRACT -->|fail| EMPTY["return []"]
    VISION -->|not configured| EMPTY

    STORE["upsert_all\nSQLite"] --> RESULT["return data"]
```

### Payment Flow

```mermaid
sequenceDiagram
    participant U as User / AI
    participant CLI as CLI / MCP Tool
    participant DB as SQLite
    participant PW as Chrome via agent-browser
    participant DL as DoorLoop
    participant AM as AgentMail

    U->>CLI: payment receive --tenant X --amount Y
    CLI->>DB: find_tenant_by_name(X)
    alt not found in DB
        CLI->>PW: list_tenants (refresh)
        PW->>DL: navigate + intercept XHR
        DL-->>PW: tenants JSON
        PW-->>CLI: tenant list
        CLI->>DB: upsert_all
    end
    CLI->>PW: fill_payment(lease_id, amount, date, method, memo)
    PW->>DL: navigate to payment form
    PW->>DL: fill form fields
    PW-->>CLI: form ready (not submitted)
    CLI-->>U: "Click Save in browser, then press Enter"
    U->>CLI: [press Enter]
    CLI->>PW: list_lease_transactions(lease_id)
    PW->>DL: navigate + intercept XHR
    DL-->>PW: transactions JSON
    PW-->>CLI: transactions
    CLI->>DB: upsert_lease_transactions
    CLI-->>U: confirmed transaction details
    opt AgentMail configured
        CLI->>AM: send_message(to, subject, body)
        AM-->>U: confirmation email
    end
```

### File Structure

```
bin/doorloop              CLI entry point (Thor)
lib/doorloop_app/
  server.rb               MCP server setup
  tool.rb                 Base tool class
  tools/                  9 MCP tools
  browser/                agent-browser runner + persistent session + page objects
    pages/                PropertiesPage, UnitsPage, TenantsPage,
                          LeasesPage, LeaseTransactionsPage, PaymentPage
  api/                    In-browser API client + discovered route registry
    endpoints/            Properties, Units, Tenants, Leases
  models/                 Sequel ORM models (SQLite)
    json_backed.rb        Shared upsert/find/stale logic
                          Property, Unit, Lease, Tenant, LeaseTransaction
  data/executor.rb        3-layer fallback orchestrator
  llm/tenant_matcher.rb   Claude AI fuzzy tenant matching
  vision/client.rb        Claude AI page text extraction
  agent_mail/client.rb    AgentMail 2FA retrieval + email sending
  notifications/          PaymentConfirmation (via AgentMail)
  cli/                    Thor CLI commands + subcommands
```

## Tests

```bash
bundle exec rake test
```

Tests use Minitest + Mocha with mock browser sessions. No live DoorLoop connection required.

To run the real local-browser test as well:

```bash
RUN_BROWSER_TESTS=1 bundle exec rake test
```

It starts a local fixture, authenticates, closes Chrome and Ruby, then starts a new process with the same profile. It verifies persistent HTTP-only cookies/local storage, network response bodies, authorization/CSRF replay, query encoding, full API records and POST requests. Set `DOORLOOP_BROWSER_EXECUTABLE` to a specific Chrome executable if needed.

## License

MIT
