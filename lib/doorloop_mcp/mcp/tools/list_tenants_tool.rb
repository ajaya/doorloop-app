# frozen_string_literal: true

module DoorloopMcp
  module MCP
    module Tools
      class ListTenantsTool < Tool
        tool "doorloop_list_tenants",
          description: "List all tenants in DoorLoop. Returns tenant names, emails, phones, and associated properties and leases.",
          input_schema: {
            properties: {
              property_id: { type: "string", description: "Filter by property ID (optional)" },
              refresh:     { type: "boolean", description: "Force fetch from DoorLoop (default: false)" }
            }
          } do |args, server_context|
          data = server_context[:service].list_tenants(
            property_id: args["property_id"],
            refresh: args.fetch("refresh", false)
          )
          data.empty? ? message_response("No tenants found.") : text_response(data)
        rescue => e
          error_response("Failed to list tenants: #{e.message}")
        end
      end
    end
  end
end
