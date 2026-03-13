# frozen_string_literal: true

module DoorLoopApp
  module Tools
    class ReceivePaymentTool < Tool
      tool "doorloop_receive_payment",
        description: "Open a payment form for a tenant in DoorLoop. Finds the tenant and lease, fills the form with amount and payment method, but does NOT submit. User must review and click Save.",
        input_schema: {
          properties: {
            tenant_name:    { type: "string", description: "Name of the tenant (partial match OK)" },
            amount:         { type: "string", description: "Payment amount (e.g., '1200.00')" },
            date:           { type: "string", description: "Payment date in YYYY-MM-DD format (defaults to today)" },
            payment_method: { type: "string", description: "Payment method (default: EFT)", enum: %w[Cash Check EFT Debit\ Card Money\ Order Other] },
            memo:           { type: "string", description: "Optional memo/note for the payment" }
          },
          required: %w[tenant_name amount]
        } do |args, server_context|
        service = server_context[:service]
        session = server_context[:session]

        session.ensure_authenticated!

        result = service.receive_payment(
          tenant_name:    args["tenant_name"],
          amount:         args["amount"],
          date:           args["date"],
          payment_method: args.fetch("payment_method", "EFT"),
          memo:           args["memo"]
        )

        if result[:status] == :ready
          text_response({
            status:         "ready_for_review",
            tenant:         result[:tenant],
            lease_id:       result[:lease_id],
            date:           result[:date],
            amount:         result[:amount],
            payment_method: result[:payment_method],
            memo:           result[:memo],
            message:        "Payment form is filled. Review in the browser and click Save to confirm."
          })
        else
          error_response(result[:message])
        end
      rescue => e
        error_response("Failed to prepare payment: #{e.message}")
      end
    end
  end
end
