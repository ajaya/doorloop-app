# frozen_string_literal: true

module DoorloopMcp
  module MCP
    module Tools
      class ListPropertiesTool < Tool
        tool "doorloop_list_properties",
          description: "List all properties in DoorLoop. Returns property ID, name, address, type, and unit count. Data is cached in local SQLite.",
          input_schema: {
            properties: {
              refresh: {
                type: "boolean",
                description: "Force fetch from DoorLoop (default: false, uses cached data)"
              }
            }
          } do |args, server_context|
          data = server_context[:service].list_properties(refresh: args.fetch("refresh", false))
          data.empty? ? message_response("No properties found.") : text_response(data)
        rescue => e
          error_response("Failed to list properties: #{e.message}")
        end
      end
    end
  end
end
