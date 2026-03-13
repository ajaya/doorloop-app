# frozen_string_literal: true

module DoorLoopApp
  module Tools
    class ListLeasesTool < Tool
      tool "doorloop_list_leases",
        description: "List leases in DoorLoop. Optionally filter by property. Returns name, status, rent, balance, start/end dates.",
        input_schema: {
          properties: {
            property_id: { type: "string", description: "Filter leases by property ID (optional)" },
            refresh:     { type: "boolean", description: "Force fetch from DoorLoop (default: false)" }
          }
        } do |args, server_context|
        data = server_context[:service].list_leases(
          property_id: args["property_id"],
          refresh: args.fetch("refresh", false)
        )
        data.empty? ? message_response("No leases found.") : text_response(data)
      rescue => e
        error_response("Failed to list leases: #{e.message}")
      end
    end
  end
end
