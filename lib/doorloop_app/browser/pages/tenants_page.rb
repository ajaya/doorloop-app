# frozen_string_literal: true

module DoorLoopApp
  module Browser
    module Pages
      class TenantsPage < PageObject
        TENANTS_PATH = "/tenants?period=all-time&period_moveOutAt=all-time"
        TENANTS_API = "/api/leases/tenants/"

        def list_all
          fetch_tenants_page(TENANTS_PATH)
        end

        private

        def fetch_tenants_page(path)
          response = page.expect_response(
            ->(resp) {
              resp.url.include?(TENANTS_API) &&
                resp.url.include?("custom-fields") &&
                !resp.url.include?("widgets") &&
                resp.status == 200
            },
            timeout: 15_000
          ) { navigate_to(path) }

          api_body = JSON.parse(response.body)
          if api_body.is_a?(Hash) && api_body["data"].is_a?(Array)
            log "Captured #{api_body["data"].length} tenants from API"
            api_body["data"]
          else
            log "Unexpected API response shape"
            []
          end
        rescue => e
          log "API capture failed (#{e.message})"
          []
        end
      end
    end
  end
end
