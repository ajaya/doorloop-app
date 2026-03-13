# frozen_string_literal: true

module DoorloopMcp
  module CLI
    class Properties < Base
      desc "list", "List all properties (reads from local DB by default)"
      long_desc <<~DESC
        Returns properties from the local SQLite cache. Use --refresh to fetch
        fresh data from DoorLoop (requires browser).

        With --raw, outputs the full JSON to stdout (pipeable).

        Examples:
          doorloop properties list
          doorloop properties list --refresh
          doorloop properties list --raw | jq '.[].name'
      DESC
      method_option :refresh, type: :boolean, default: false, aliases: "-f",
                              desc: "Fetch fresh data from DoorLoop before listing"
      method_option :raw, type: :boolean, default: false, aliases: "-r",
                          desc: "Output raw JSON instead of formatted table"
      def list
        data = DoorloopMcp.service.list_properties(refresh: options[:refresh])
        empty_db_error("doorloop properties list") if data.empty?

        if options[:raw]
          print_json(data)
        else
          rows = data.map { |p| [p[:name], p[:type], p[:numActiveUnits], format_address(p[:address])] }
          print_table_data(rows, %w[NAME TYPE UNITS ADDRESS])
        end
      end

      private

      def format_address(addr)
        return nil unless addr.is_a?(Hash)

        addr.values_at(:street1, :city, :state, :zip).compact.reject(&:empty?).join(", ")
      end
    end
  end
end
