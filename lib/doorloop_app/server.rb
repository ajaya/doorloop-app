# frozen_string_literal: true

require "mcp"

module DoorLoopApp
  module Server
    DEFAULT_HTTP_PORT = 9293

    TOOL_CLASSES = [
      -> { Tools::LoginTool },
      -> { Tools::Submit2faTool },
      -> { Tools::ListPropertiesTool },
      -> { Tools::ListUnitsTool },
      -> { Tools::ListTenantsTool },
      -> { Tools::ListLeasesTool },
      -> { Tools::FindTenantTool },
      -> { Tools::ReceivePaymentTool },
      -> { Tools::ListLeaseTransactionsTool }
    ].freeze

    def self.build
      config = DoorLoopApp.configuration

      # Browser layer (Playwright)
      session = Browser::Session.new

      # API layer (direct HTTP)
      token_store = Api::TokenStore.new(session_dir: File.dirname(config.db_path))
      api_registry = Api::Registry.new
      api_client = api_registry.discovered? ? Api::Client.new(token_store: token_store, registry: api_registry) : nil

      # Vision layer (Claude AI fallback)
      vision_client = config.vision_configured? ? Vision::Client.new : nil

      # Storage layer (SQLite)
      store = Store.new(db_path: config.db_path)

      # Executor (3-layer fallback + storage)
      executor = Data::Executor.new(
        session: session,
        api_client: api_client,
        token_store: token_store,
        vision_client: vision_client,
        store: store
      )

      # Shared service layer used by all MCP tools
      service = Service.new(executor: executor, store: store)

      at_exit { session.stop }

      all_tools = TOOL_CLASSES.flat_map { |tc| tc.call.mcp_tools }

      ::MCP::Server.new(
        name: "doorloop-mcp",
        version: DoorLoopApp::VERSION,
        tools: all_tools,
        server_context: {
          session:,
          executor:,
          store:,
          service:,
          token_store:
        }
      )
    end

    def self.run(http: false, port: DEFAULT_HTTP_PORT)
      server = build
      print_banner(server, http:, port:)

      if http
        start_http(server, port)
      else
        start_stdio(server)
      end
    end

    def self.start_stdio(server)
      transport = ::MCP::Server::Transports::StdioTransport.new(server)
      transport.open
    end

    def self.start_http(server, port)
      require "rack"
      require "webrick"

      transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(server)
      server.transport = transport

      app = ->(env) { transport.handle_request(Rack::Request.new(env)) }

      require "rackup/handler/webrick"
      Rackup::Handler::WEBrick.run(
        Rack::Builder.new { map("/mcp") { run app } },
        Host: "127.0.0.1",
        Port: port,
        Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
        AccessLog: []
      )
    end

    private_class_method :start_stdio, :start_http

    def self.color?
      $stderr.tty?
    end

    def self.c(code)
      color? ? code : ""
    end

    def self.print_banner(server, http: false, port: DEFAULT_HTTP_PORT)
      bold = c("\e[1m")
      dim = c("\e[2m")
      reset = c("\e[0m")
      green = c("\e[32m")
      cyan = c("\e[36m")

      total = server.tools.size
      transport_label = http ? "http (port #{port})" : "stdio"
      config = DoorLoopApp.configuration

      warn "#{green}#{bold}doorloop#{reset} MCP server #{dim}v#{DoorLoopApp::VERSION}#{reset}"
      warn ""
      warn "#{dim}Email:#{reset}     #{config.email}"
      warn "#{dim}URL:#{reset}       #{config.url}"
      warn "#{dim}DB:#{reset}        #{config.db_path.sub(Dir.home, "~")}"
      warn "#{dim}Headless:#{reset}  #{config.headless?}"
      warn ""
      warn "#{dim}Ruby:#{reset}      #{RbConfig.ruby}"
      warn "#{dim}Version:#{reset}   #{RUBY_VERSION}"
      warn ""
      warn "#{dim}Transport:#{reset} #{transport_label}"
      warn "#{dim}Tools:#{reset}     #{total}"

      TOOL_CLASSES.each do |tc|
        klass = tc.call
        klass.tools.each do |t|
          warn "  #{cyan}#{t[:name]}#{reset}"
        end
      end

      warn ""
      if http
        warn "#{green}Ready#{reset} #{dim}— listening on http://127.0.0.1:#{port}/mcp#{reset}"
      else
        warn "#{green}Ready#{reset} #{dim}— waiting for JSON-RPC requests on stdin...#{reset}"
      end
    end
  end
end
