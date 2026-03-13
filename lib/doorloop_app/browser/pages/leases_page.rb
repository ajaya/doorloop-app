# frozen_string_literal: true

module DoorLoopApp
  module Browser
    module Pages
      class LeasesPage < PageObject
        LEASES_PATH = "/leases/active-leases?filter_status=ACTIVE&sort_by=name"
        LEASES_API = "/api/leases/"

        def list_all(property_id: nil)
          fetch_leases_page(LEASES_PATH)
        end

        private

        def fetch_leases_page(path)
          response = page.expect_response(
            ->(resp) {
              resp.url.include?(LEASES_API) &&
                resp.url.include?("filter_status") &&
                resp.status == 200
            },
            timeout: 15_000
          ) { navigate_to(path) }

          api_body = JSON.parse(response.body)
          if api_body.is_a?(Hash) && api_body["data"].is_a?(Array)
            log "Captured #{api_body["data"].length} leases from API"
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
