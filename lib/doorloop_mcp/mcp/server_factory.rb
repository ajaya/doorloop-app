# frozen_string_literal: true

require "mcp"

module DoorloopMcp
  module MCP
    class ServerFactory
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
        config = DoorloopMcp.configuration

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
          version: DoorloopMcp::VERSION,
          tools: all_tools,
          server_context: {
            session:      session,
            executor:     executor,
            store:        store,
            service:      service,
            token_store:  token_store
          }
        )
      end
    end
  end
end
