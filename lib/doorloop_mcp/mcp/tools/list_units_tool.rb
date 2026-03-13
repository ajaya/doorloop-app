# frozen_string_literal: true

module DoorloopMcp
  module MCP
    module Tools
      class ListUnitsTool < Tool
        tool "doorloop_list_units",
          description: "List all units in DoorLoop. Optionally filter by property ID. Returns unit name, status, rent, and lease status.",
          input_schema: {
            properties: {
              property_id: { type: "string", description: "Filter by property ID (optional)" },
              refresh:     { type: "boolean", description: "Force fetch from DoorLoop (default: false)" }
            }
          } do |args, server_context|
          data = server_context[:service].list_units(
            property_id: args["property_id"],
            refresh: args.fetch("refresh", false)
          )
          data.empty? ? message_response("No units found.") : text_response(data)
        rescue => e
          error_response("Failed to list units: #{e.message}")
        end
      end
    end
  end
end
