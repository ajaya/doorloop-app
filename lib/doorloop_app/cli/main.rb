# frozen_string_literal: true

module DoorLoopApp
  module CLI
    class Main < Base
      desc "version", "Show DoorLoop MCP version"
      def version
        say "doorloop-mcp v#{DoorLoopApp::VERSION}"
      end

      desc "server", "Start the MCP server (stdio by default, --http for HTTP)"
      long_desc <<~DESC
        Starts the MCP server for use with Claude Desktop or other MCP clients.
        Default transport is stdio (JSON-RPC on stdin/stdout); use --http for HTTP.
        All logs go to stderr.
      DESC
      method_option :http, type: :boolean, default: false, desc: "Listen on HTTP instead of stdio"
      method_option :port, type: :numeric, default: DoorLoopApp::Server::DEFAULT_HTTP_PORT,
        desc: "HTTP port (default: #{DoorLoopApp::Server::DEFAULT_HTTP_PORT})"
      def server
        Server.run(http: options[:http], port: options[:port])
      end

      desc "login", "Login to DoorLoop (saves session to Chrome profile)"
      long_desc <<~DESC
        Opens a browser, logs in to DoorLoop with credentials from .env.local,
        and saves the session to the Chrome profile directory so future commands
        can skip authentication.
      DESC
      def login
        config = DoorLoopApp.configuration
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
          DoorLoopApp.session    — Playwright browser session
          DoorLoopApp.store      — SQLite model store
          DoorLoopApp.executor   — 3-layer data executor
          DoorLoopApp.configuration
      DESC
      def console
        require "irb"
        require "awesome_print" rescue nil
        require "pry" rescue nil

        config = DoorLoopApp.configuration
        DoorLoopApp.session.start

        say "DoorLoop MCP console"
        say "  DoorLoopApp.configuration — config"
        say "  DoorLoopApp.session       — browser session"
        say "  DoorLoopApp.store         — SQLite store"
        say "  DoorLoopApp.executor      — data executor"
        say ""
        say "  email=#{config.email}, url=#{config.url}"
        say ""

        ARGV.clear
        IRB.start
      ensure
        DoorLoopApp.session&.stop
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
