# frozen_string_literal: true

module DoorLoopApp
  module Tools
    class FindTenantTool < Tool
      tool "doorloop_find_tenant",
        description: "Search for a tenant by name in DoorLoop. Uses local DB with LLM fuzzy matching fallback. Pass refresh: true to sync from DoorLoop first.",
        input_schema: {
          properties: {
            query:   { type: "string",  description: "Name (or partial name) to search for" },
            refresh: { type: "boolean", description: "Fetch latest tenant data from DoorLoop before searching (default: false)" }
          },
          required: ["query"]
        } do |args, server_context|
        results = server_context[:service].find_tenant(args["query"], refresh: args.fetch("refresh", false))
        results.empty? ? message_response("No tenants found matching '#{args["query"]}'.") : text_response(results)
      rescue => e
        error_response("Failed to find tenant: #{e.message}")
      end
    end
  end
end
