# frozen_string_literal: true

module DoorloopMcp
  module CLI
    class Units < Base
      desc "list", "List all units (reads from local DB by default)"
      long_desc <<~DESC
        Returns units from the local SQLite cache. Use --refresh to fetch
        fresh data from DoorLoop (requires browser).

        With --property, filters by property ID.
        With --raw, outputs full JSON to stdout (pipeable).

        Examples:
          doorloop units list
          doorloop units list --refresh
          doorloop units list --property abc123
          doorloop units list --raw | jq '.[].unitName'
      DESC
      method_option :refresh,  type: :boolean, default: false, aliases: "-f",
                               desc: "Fetch fresh data from DoorLoop before listing"
      method_option :property, type: :string,  aliases: "-p",
                               desc: "Filter by property ID"
      method_option :raw,      type: :boolean, default: false, aliases: "-r",
                               desc: "Output raw JSON instead of formatted table"
      def list
        data = DoorloopMcp.service.list_units(property_id: options[:property], refresh: options[:refresh])
        empty_db_error("doorloop units list") if data.empty?

        if options[:raw]
          print_json(data)
        else
          rows = data.map { |u| [u[:unitName] || u[:name], u[:property], u[:leaseStatus] || u[:status], u[:marketRent] || u[:rent]] }
          print_table_data(rows, %w[NAME PROPERTY STATUS RENT])
        end
      end
    end
  end
end
