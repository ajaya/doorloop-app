# Claude and Codex MCP connections

Checked November 15, 2026 against the official client documentation and MCP specification.

The app uses the official Ruby MCP SDK 1.10.0. It serves the current 2026-07-28 protocol (per-request metadata and `server/discover`) and older handshake-based clients, including 2025-11-25. The SDK handles version validation and negotiation. Both stdio and Streamable HTTP are tested against both protocol generations.

## Choose a transport

| Transport | Start | Client connection |
| --- | --- | --- |
| stdio | Client launches `bin/doorloop server` | Newline-delimited JSON-RPC on stdin/stdout; diagnostics on stderr |
| HTTP | Run `bin/doorloop server --http` | `http://127.0.0.1:9293/mcp`, Streamable HTTP with JSON responses |

HTTP is stateless at the MCP layer. The Chrome profile, encrypted browser restore state and SQLite cache persist independently. Use one shared HTTP server when Claude and Codex should connect to the same running app. Avoid concurrent browser workflows against a single profile.

Both transports expose the same nine tools, input validation, read-only annotations, human-readable text and structured JSON results. Login/2FA and payment-form preparation are marked as state-changing; receiving a payment still requires the manual Save action.

## stdio setup

Run these from the repository directory. `mise -C` pins the working directory and Ruby version even when the client launches elsewhere:

```bash
claude mcp add --transport stdio doorloop-stdio -- \
  mise -C "$PWD" exec ruby@4.0.9 -- bundle exec bin/doorloop server

codex mcp add doorloop-stdio -- \
  mise -C "$PWD" exec ruby@4.0.9 -- bundle exec bin/doorloop server
```

If a GUI client cannot find `mise`, use its absolute executable path. The entry point locates the app's Gemfile and dotenv files relative to the repository, and silences Bundler's setup messages so stdout stays valid MCP traffic.

## HTTP setup

Start the server in a terminal or service manager:

```bash
bundle exec bin/doorloop server --http --port 9293
```

Register it with the clients:

```bash
claude mcp add --transport http doorloop-http http://127.0.0.1:9293/mcp
codex mcp add doorloop-http --url http://127.0.0.1:9293/mcp
```

Equivalent Codex `config.toml` entry:

```toml
[mcp_servers.doorloop]
url = "http://127.0.0.1:9293/mcp"
```

Equivalent Claude MCP JSON entry:

```json
{
  "mcpServers": {
    "doorloop": {
      "type": "http",
      "url": "http://127.0.0.1:9293/mcp"
    }
  }
}
```

Choose one connection per client to avoid duplicate tool catalogs. The HTTP listener defaults to loopback and the SDK validates Host/Origin headers. The optional Docker HTTP service publishes only to host loopback:

```bash
docker compose --profile http up mcp-http
```

## Models and cost

Choose the Claude or Codex model in the respective client. The MCP server works independently of that selection and does not need an OpenAI or Anthropic API key for browser operations.

The app's optional Claude fallback uses official `anthropic` SDK 2.8.0 with prompt caching. Defaults are `claude-haiku-5-5` for tenant matching and `claude-sonnet-5-5` for vision extraction. Model overrides remain available through `DOORLOOP_LLM_MODEL` and `DOORLOOP_VISION_MODEL`. These calls remain disabled unless `DOORLOOP_ALLOW_PAID_AI=true` and an Anthropic API key is configured. Updating the app does not enable paid calls.

## Process lifecycle and verification

Closing stdin ends a stdio server. Stop the HTTP server with Ctrl-C or SIGTERM. Normal shutdown saves encrypted browser state, including session-only cookies and tab storage. DoorLoop can still revoke or expire an authenticated session; `login --manual` handles reauthentication.

```bash
bundle exec rake test
RUN_BROWSER_TESTS=1 bundle exec rake test
```

The tests launch real server processes for HTTP and stdio, exercise modern discovery and legacy initialization, list/call tools, validate structured responses, reject unexpected arguments, and check HTTP Origin protection and unsupported protocol versions. The optional browser test uses a local fixture and incurs no model API charges.

Sources: [MCP specification](https://modelcontextprotocol.io/specification/2026-07-28), [Ruby SDK](https://ruby.sdk.modelcontextprotocol.io/), [Codex MCP documentation](https://developers.openai.com/codex/mcp/), [Claude Code MCP documentation](https://code.claude.com/docs/en/mcp), [Claude models](https://platform.claude.com/docs/en/models/overview), [official Anthropic Ruby SDK](https://github.com/anthropics/anthropic-sdk-ruby).
