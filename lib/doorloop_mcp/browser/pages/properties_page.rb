# frozen_string_literal: true

module DoorloopMcp
  module Browser
    module Pages
      class PropertiesPage < PageObject
        PROPERTIES_PATH = "/properties"
        PROPERTIES_API = "/api/properties/custom-fields"

        def list_all
          response = page.expect_response(
            ->(resp) { resp.url.include?(PROPERTIES_API) && resp.status == 200 },
            timeout: 15_000
          ) { navigate_to(PROPERTIES_PATH) }

          api_body = JSON.parse(response.body)
          if api_body["data"].is_a?(Array)
            log "Captured #{api_body["data"].length} properties from API"
            api_body["data"].select { |item| item["id"] }
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
