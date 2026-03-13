# frozen_string_literal: true

module DoorloopMcp
  module CLI
    class Tenants < Base
      desc "list", "List all tenants (reads from local DB by default)"
      long_desc <<~DESC
        Returns tenants from the local SQLite cache. Use --refresh to fetch
        fresh data from DoorLoop (requires browser).

        With --property, filters by property ID.
        With --raw, outputs full JSON to stdout (pipeable).

        Examples:
          doorloop tenants list
          doorloop tenants list --refresh
          doorloop tenants list --property abc123
          doorloop tenants list --raw | jq '.[].name'
      DESC
      method_option :refresh,  type: :boolean, default: false, aliases: "-f",
                               desc: "Fetch fresh data from DoorLoop before listing"
      method_option :property, type: :string,  aliases: "-p",
                               desc: "Filter by property ID"
      method_option :raw,      type: :boolean, default: false, aliases: "-r",
                               desc: "Output raw JSON instead of formatted table"
      def list
        data = DoorloopMcp.service.list_tenants(property_id: options[:property], refresh: options[:refresh])
        empty_db_error("doorloop tenants list") if data.empty?

        if options[:raw]
          print_json(data)
        else
          rows = data.map do |t|
            email = t.dig(:tenant, :emails, 0, :address) || t[:email]
            phone = t.dig(:tenant, :phones, 0, :number) || t[:phone]
            [t[:name], email, phone, t[:status], t[:balanceDue] || t[:balance_due]]
          end
          print_table_data(rows, %w[NAME EMAIL PHONE STATUS BALANCE])
        end
      end

      desc "find QUERY", "Search for a tenant by name (DB search + LLM fallback)"
      long_desc <<~DESC
        Searches the local DB for a tenant by name. Falls back to LLM fuzzy
        matching if no exact match found. Use --refresh to fetch fresh data
        from DoorLoop first.

        No browser is opened unless --refresh is passed.

        With --raw, outputs matching tenant(s) as JSON.

        Examples:
          doorloop tenants find "Prayag"
          doorloop tenants find "P. Bansal" --raw
          doorloop tenants find "Prayag" --refresh
      DESC
      method_option :refresh, type: :boolean, default: false, aliases: "-f",
                              desc: "Fetch fresh data from DoorLoop before searching"
      method_option :raw,     type: :boolean, default: false, aliases: "-r",
                              desc: "Output raw JSON instead of formatted table"
      def find(query)
        results = DoorloopMcp.service.find_tenant(query, refresh: options[:refresh])

        if results.empty?
          say_error "No tenant found matching '#{query}'. Try --refresh to sync from DoorLoop."
          exit 1
        end

        if options[:raw]
          print_json(results)
        else
          rows = results.map do |t|
            email = t.dig(:tenant, :emails, 0, :address) || t[:email]
            phone = t.dig(:tenant, :phones, 0, :number) || t[:phone]
            [t[:name], t[:id], email, phone, t[:status], t[:lease]]
          end
          print_table_data(rows, %w[NAME ID EMAIL PHONE STATUS LEASE_ID])
        end
      end
    end
  end
end
