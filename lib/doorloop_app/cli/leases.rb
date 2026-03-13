# frozen_string_literal: true

module DoorLoopApp
  module CLI
    class Leases < Base
      desc "list", "List all active leases (reads from local DB by default)"
      long_desc <<~DESC
        Returns leases from the local SQLite cache. Use --refresh to fetch
        fresh data from DoorLoop (requires browser).

        With --property, filters by property ID.
        With --raw, outputs full JSON to stdout (pipeable).

        Examples:
          doorloop leases list
          doorloop leases list --refresh
          doorloop leases list --property abc123
          doorloop leases list --raw | jq '.[].name'
      DESC
      method_option :refresh,  type: :boolean, default: false, aliases: "-f",
                               desc: "Fetch fresh data from DoorLoop before listing"
      method_option :property, type: :string,  aliases: "-p",
                               desc: "Filter by property ID"
      method_option :raw,      type: :boolean, default: false, aliases: "-r",
                               desc: "Output raw JSON instead of formatted table"
      def list
        data = DoorLoopApp.service.list_leases(property_id: options[:property], refresh: options[:refresh])
        empty_db_error("doorloop leases list") if data.empty?

        if options[:raw]
          print_json(data)
        else
          rows = data.map do |l|
            [l[:name], l[:property], l[:status],
             l[:totalRecurringRent] || l[:total_rent],
             l[:totalBalanceDue] || l[:balance],
             l[:start], l[:end]]
          end
          print_table_data(rows, %w[NAME PROPERTY STATUS RENT BALANCE START END])
        end
      end

      desc "transactions", "List transactions for a tenant's lease"
      long_desc <<~DESC
        Looks up the tenant by name, finds their lease, then fetches all
        transactions from DoorLoop via browser (always requires live session).

        Tenant lookup order:
          1. DB name search (fast)
          2. Refresh from DoorLoop + retry
          3. LLM fuzzy match (requires ANTHROPIC_API_KEY)

        With --lease-id, tenant lookup is skipped entirely.
        With --raw, outputs JSON to stdout (pipeable).

        Examples:
          doorloop leases transactions --tenant "Shital"
          doorloop leases transactions --tenant "Shital" --raw | jq '.[].amount'
          doorloop leases transactions --lease-id abc123
      DESC
      method_option :tenant,   type: :string, aliases: "-t",
                               desc: "Tenant name to search for"
      method_option :lease_id, type: :string, aliases: "-l",
                               desc: "Lease ID (skips tenant lookup)"
      method_option :raw,      type: :boolean, default: false, aliases: "-r",
                               desc: "Output raw JSON instead of formatted table"
      def transactions
        unless options[:tenant] || options[:lease_id]
          say_error "Must provide --tenant or --lease-id"
          exit 1
        end

        run_with_session do
          lease_id = options[:lease_id] || resolve_lease_id_for_tenant(options[:tenant])

          say "Fetching transactions for lease #{lease_id}..."
          data = DoorLoopApp.service.list_lease_transactions(lease_id: lease_id)

          if data.empty?
            say_error "No transactions found for lease #{lease_id}."
            exit 1
          end

          if options[:raw]
            print_json(data)
          else
            rows = data.map do |t|
              memo = t.dig("lines", 0, "memo") || t.dig(:lines, 0, :memo)
              [t["date"], t["type"], "$#{t["totalAmount"]}", t["reference"], memo, t["runningBalance"]]
            end
            print_table_data(rows, %w[DATE TYPE AMOUNT REFERENCE MEMO BALANCE])
          end
        end
      end

      private

      def resolve_lease_id_for_tenant(name)
        # DB search first (service handles DB + LLM fallback)
        results = DoorLoopApp.service.find_tenant(name)

        if results.empty?
          say "Tenant '#{name}' not in DB — refreshing from DoorLoop..."
          results = DoorLoopApp.service.find_tenant(name, refresh: true)
        end

        if results.empty?
          say_error "No tenant found matching '#{name}'. Try `doorloop tenants list --refresh` first."
          exit 1
        end

        tenant = results.first
        lease_id = tenant[:lease].to_s
        if lease_id.empty?
          say_error "Tenant '#{tenant[:name]}' has no associated lease."
          exit 1
        end

        say "Resolved '#{name}' → #{tenant[:name]} (lease: #{lease_id})"
        lease_id
      end
    end
  end
end
