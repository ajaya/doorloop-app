# frozen_string_literal: true

module DoorLoopApp
  module Browser
    module Pages
      class LeaseTransactionsPage < PageObject
        TRANSACTIONS_PATH = "/leases/active-leases/%s/transactions?period=all-time&filter_lease=%s"
        LEASES_PATH       = "/leases/active-leases"
        TRANSACTIONS_API  = "/api/reports/lease-accounts-receivable/"

        def list_all(lease_id:)
          path = TRANSACTIONS_PATH % [lease_id, lease_id]

          # If already on the transactions page (e.g. DoorLoop auto-redirected here
          # after payment save), React Router won't re-fire the XHR on same-URL
          # navigation. Navigate away first to force a fresh XHR.
          if page.url.include?("/transactions")
            log "Already on transactions page — navigating away to force XHR refresh"
            navigate_to(LEASES_PATH)
            sleep 1
          end

          response = page.expect_response(
            ->(resp) {
              resp.url.include?(TRANSACTIONS_API) &&
                resp.url.include?("filter_lease") &&
                resp.status == 200
            },
            timeout: 20_000
          ) { navigate_to(path) }

          api_body = JSON.parse(response.body)
          if api_body.is_a?(Hash) && api_body["data"].is_a?(Array)
            log "Captured #{api_body["data"].length} transactions for lease #{lease_id}"
            # Inject lease_id into each item — not present in API response but
            # needed for the LeaseTransaction model's lease_id indexed column.
            api_body["data"].map { |t| t.merge("lease" => lease_id) }
          else
            log "Unexpected API response shape: #{api_body.keys rescue api_body.class}"
            []
          end
        rescue => e
          log "Transactions API capture failed: #{e.class}: #{e.message}"
          []
        end
      end
    end
  end
end
