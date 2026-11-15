# Changelog

## Unreleased

- Align local and Docker runtimes on Ruby 4.0.9 and Bundler 4.0.24.
- Update gems, including MCP 1.10, RubyLLM 2.2, Sequel 5.110, Minitest 6.1, and Mocha 3.1.
- Align npm Playwright 1.64.0 with playwright-ruby-client 1.64.x.
- Track dependency manifests and lockfiles, including Linux platforms for Docker.
- Remove unused instructor-rb and its legacy dependency tree.
- Fix model loading before Store initialization and use Ruby 4's CGI escape entry point.

## 0.1.0 — Initial Release

First release of `doorloop-app`, an MCP server for DoorLoop property management.

### Features

- 9 MCP tools: login, submit_2fa, list_properties, list_units, list_tenants, list_leases, find_tenant, receive_payment, list_lease_transactions
- 3-layer data retrieval: Direct API, Playwright browser automation, Claude AI vision fallback
- SQLite caching with Sequel ORM
- Thor CLI with subcommands for properties, units, tenants, leases, and payments
- AgentMail integration for automatic 2FA retrieval and payment confirmation emails
- LLM-powered fuzzy tenant matching (Claude Haiku)
- Docker support with multi-stage build (Ruby 4.0 + Node.js 22 + Chromium)
- Persistent Chrome session for seamless re-authentication
