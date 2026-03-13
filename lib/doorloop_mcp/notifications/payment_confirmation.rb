# frozen_string_literal: true

module DoorloopMcp
  module Notifications
    class PaymentConfirmation
      def self.send!(transactions:, tenant_name:, config:)
        new(transactions: transactions, tenant_name: tenant_name, config: config).deliver!
      end

      def initialize(transactions:, tenant_name:, config:)
        @transactions = transactions
        @tenant_name  = tenant_name
        @config       = config
      end

      def deliver!
        client = AgentMail::Client.new
        client.send_message(
          to:      @config.confirmation_email_to,
          subject: "Payment Confirmation — #{@tenant_name}",
          text:    build_body
        )
        $stderr.puts "[Notifications] Sent payment confirmation to #{@config.confirmation_email_to}"
      rescue => e
        $stderr.puts "[Notifications] Failed to send confirmation email: #{e.message}"
        raise
      end

      private

      def build_body
        lines = [
          "Payment Confirmation",
          "=" * 50,
          "Tenant: #{@tenant_name}",
          ""
        ]

        @transactions.each_with_index do |t, i|
          lines << "Transaction #{i + 1}:" if @transactions.size > 1
          lines << "  ID:          #{t["id"] || t[:id]}"
          lines << "  Date:        #{t["date"] || t[:date]}"
          lines << "  Amount:      $#{t["amount"] || t[:amount]}"
          lines << "  Type:        #{t["type"] || t[:txn_type]}"
          lines << "  Description: #{t["description"] || t[:description]}"
          lines << "  Status:      #{t["status"] || t[:status]}"
          lines << ""
        end

        lines << "—"
        lines << "Sent by doorloop-mcp"
        lines.join("\n")
      end
    end
  end
end
