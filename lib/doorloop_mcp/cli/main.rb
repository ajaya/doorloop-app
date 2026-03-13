# frozen_string_literal: true

module DoorloopMcp
  module CLI
    class Main < Base
      desc "version", "Show DoorLoop MCP version"
      def version
        say "doorloop-mcp v#{DoorloopMcp::VERSION}"
      end

      desc "server", "Start the MCP server (stdio transport)"
      long_desc <<~DESC
        Starts the MCP stdio server for use with Claude Desktop or other MCP clients.
        All JSON-RPC communication happens on stdout; logs go to stderr.
      DESC
      def server
        CLI::Config.print!
        say "Starting DoorLoop MCP server v#{DoorloopMcp::VERSION}..."
        server = MCP::ServerFactory.build
        transport = ::MCP::Server::Transports::StdioTransport.new(server)
        transport.open
      end

      desc "login", "Login to DoorLoop (saves session to Chrome profile)"
      long_desc <<~DESC
        Opens a browser, logs in to DoorLoop with credentials from .env.local,
        and saves the session to the Chrome profile directory so future commands
        can skip authentication.
      DESC
      def login
        config = DoorloopMcp.configuration
        config.validate!

        say "Logging in to #{config.url} as #{config.email}..."
        session = Browser::Session.new
        begin
          session.start
          session.authenticate!
          say "Login successful! Session saved."
        rescue => e
          say_error "Login failed: #{e.message}"
          exit 1
        ensure
          session.stop
        end
      end

      desc "console", "Open a Ruby console with DoorLoop MCP loaded"
      long_desc <<~DESC
        Opens an IRB console with all DoorLoop MCP singletons pre-loaded.
        Useful for debugging, exploring data, or testing browser interactions.

        Available objects:
          DoorloopMcp.session    — Playwright browser session
          DoorloopMcp.store      — SQLite model store
          DoorloopMcp.executor   — 3-layer data executor
          DoorloopMcp.configuration
      DESC
      def console
        require "irb"
        require "awesome_print" rescue nil
        require "pry" rescue nil

        config = DoorloopMcp.configuration
        DoorloopMcp.session.start

        say "DoorLoop MCP console"
        say "  DoorloopMcp.configuration — config"
        say "  DoorloopMcp.session       — browser session"
        say "  DoorloopMcp.store         — SQLite store"
        say "  DoorloopMcp.executor      — data executor"
        say ""
        say "  email=#{config.email}, url=#{config.url}"
        say ""

        ARGV.clear
        IRB.start
      ensure
        DoorloopMcp.session&.stop
      end

      desc "config [COMMAND]", "Show current configuration"
      subcommand "config", CLI::Config

      desc "properties COMMAND", "Manage properties"
      subcommand "properties", CLI::Properties

      desc "units COMMAND", "Manage units"
      subcommand "units", CLI::Units

      desc "tenants COMMAND", "Manage tenants"
      subcommand "tenants", CLI::Tenants

      desc "leases COMMAND", "Manage leases"
      subcommand "leases", CLI::Leases

      desc "payment COMMAND", "Payment operations"
      subcommand "payment", CLI::Payment
    end
  end
end
