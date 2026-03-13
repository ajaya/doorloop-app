# frozen_string_literal: true

module DoorLoopApp
  module CLI
    class Payment < Base
      desc "receive", "Open payment form for a tenant in the browser"
      long_desc <<~DESC
        Navigates to the DoorLoop payment form for the given tenant, fills in
        the amount, date, payment method, and optional memo.

        The form is filled but NOT submitted — review in the browser and click
        Save. After pressing Enter, transactions are refreshed to confirm the
        payment. A confirmation email is sent via AgentMail if configured
        (requires AGENTMAIL_API_KEY + AGENTMAIL_INBOX_ID +
        DOORLOOP_CONFIRMATION_EMAIL_TO).

        Tenant lookup order:
          1. DB name search (fast, no browser needed)
          2. Refresh from DoorLoop + retry DB search
          3. LLM fuzzy match (requires ANTHROPIC_API_KEY)

        If --lease-id is provided, tenant lookup is skipped entirely.

        With --raw, all output (form state + confirmed transaction) is JSON.

        Examples:
          doorloop payment receive --tenant "Prayag Bansal" --amount 4500
          doorloop payment receive --tenant "Prayag" --amount 4500 --date 2026-03-01 --memo "March rent"
          doorloop payment receive --lease-id abc123 --tenant "Prayag" --amount 1500 --method EFT
          doorloop payment receive --tenant "Prayag" --amount 4500 --raw
      DESC
      method_option :tenant,   type: :string,  required: false, aliases: "-t", desc: "Tenant name to search for"
      method_option :amount,   type: :string,  required: true,  aliases: "-a", desc: "Payment amount (e.g. 4500 or 4500.00)"
      method_option :lease_id, type: :string,  required: false, aliases: "-l", desc: "Lease ID (skips tenant lookup)"
      method_option :date,     type: :string,  required: false, aliases: "-d", desc: "Payment date in YYYY-MM-DD format (default: today)"
      method_option :method,   type: :string,  default: "EFT",  aliases: "-m", desc: "Payment method (default: EFT)"
      method_option :memo,     type: :string,  required: false,                desc: "Optional memo/note"
      method_option :raw,      type: :boolean, default: false,  aliases: "-r", desc: "Output result as JSON"
      def receive
        unless options[:tenant] || options[:lease_id]
          say_error "Must provide --tenant or --lease-id"
          exit 1
        end

        raw = options[:raw]

        run_with_session do
          result = DoorLoopApp.service.receive_payment(
            lease_id:       options[:lease_id],
            tenant_name:    options[:tenant],
            amount:         options[:amount],
            date:           options[:date],
            payment_method: options[:method],
            memo:           options[:memo]
          )

          if result[:status] == :error
            say_error result[:message]
            exit 1
          end

          if raw
            $stderr.puts JSON.generate(result)
          else
            $stdout.puts "\nPayment form filled — review and click Save in the browser:"
            $stdout.puts "  Lease:   #{result[:lease_id]}"
            $stdout.puts "  Tenant:  #{result[:tenant]}"
            $stdout.puts "  Date:    #{result[:date]}"
            $stdout.puts "  Amount:  #{result[:amount]}"
            $stdout.puts "  Method:  #{result[:payment_method]}"
            $stdout.puts "  Memo:    #{result[:memo]}" if result[:memo]
          end

          lease_id    = result[:lease_id]
          tenant_name = result[:tenant] || options[:tenant]

          $stderr.print "\nClick Save in the browser, then press Enter to confirm... "
          $stdin.gets

          confirm_payment(lease_id, tenant_name, options[:amount], raw: raw)
        end
      end

      private

      def confirm_payment(lease_id, tenant_name, amount, raw: false)
        say "Fetching transactions for lease #{lease_id}..."
        matching = DoorLoopApp.service.confirm_payment(lease_id: lease_id, amount: amount)

        if matching.empty?
          target = amount.to_s.gsub(/[^0-9.]/, "").to_f
          say "No transaction matching $#{target} found. The payment may not have been saved."
          return
        end

        if raw
          print_json({ confirmed: true, transactions: matching })
        else
          $stdout.puts "\nPayment confirmed (#{matching.size} transaction(s)):"
          matching.each do |t|
            $stdout.puts "  ID:          #{t["id"]}"
            $stdout.puts "  Date:        #{t["date"]}"
            $stdout.puts "  Amount:      $#{t["totalAmount"]}"
            $stdout.puts "  Type:        #{t["type"]}"
            $stdout.puts "  Reference:   #{t["reference"]}"
            memo = t.dig("lines", 0, "memo") || t.dig(:lines, 0, :memo)
            $stdout.puts "  Memo:        #{memo}" if memo
          end
        end

        result = DoorLoopApp.service.send_payment_confirmation(transactions: matching, tenant_name: tenant_name)
        if result[:sent]
          say "\nConfirmation email sent to #{result[:to]}."
        else
          say "\nEmail notifications not configured — skipping."
          say "Set AGENTMAIL_API_KEY, AGENTMAIL_INBOX_ID, and DOORLOOP_CONFIRMATION_EMAIL_TO in .env.local to enable."
        end
      end
    end
  end
end
