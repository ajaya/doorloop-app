# frozen_string_literal: true

module DoorLoopApp
  module Tools
    class ListLeaseTransactionsTool < Tool
      tool "doorloop_list_lease_transactions",
        description: "List all transactions for a specific lease in DoorLoop.",
        input_schema: {
          properties: {
            lease_id: { type: "string", description: "The lease ID to fetch transactions for" }
          },
          required: ["lease_id"]
        } do |args, server_context|
        service = server_context[:service]
        transactions = service.list_lease_transactions(lease_id: args["lease_id"])

        if transactions.nil? || transactions.empty?
          message_response("No transactions found for lease #{args["lease_id"]}.")
        else
          text_response(transactions)
        end
      rescue => e
        error_response("Failed to list lease transactions: #{e.message}")
      end
    end
  end
end
