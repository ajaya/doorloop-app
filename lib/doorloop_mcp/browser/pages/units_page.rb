# frozen_string_literal: true

module DoorloopMcp
  module Browser
    module Pages
      class UnitsPage < PageObject
        UNITS_PATH = "/units?filter_text_searchByProperty=true&filter_properties=%s"
        ALL_UNITS_PATH = "/units"
        UNITS_API = "/api/units/leases/custom-fields"

        def list_all(property_id: nil)
          if property_id
            list_for_property(property_id)
          else
            list_all_properties
          end
        end

        private

        def list_all_properties
          property_ids = Models::Property.dataset.select_map(:id)
          if property_ids.empty?
            log "No properties in store, fetching all units from /units"
            return fetch_units_page(ALL_UNITS_PATH)
          end

          all_units = []
          property_ids.each do |pid|
            all_units.concat(list_for_property(pid))
          end
          log "Fetched #{all_units.length} units across #{property_ids.length} properties"
          all_units
        end

        def list_for_property(property_id)
          fetch_units_page(UNITS_PATH % property_id)
        end

        def fetch_units_page(path)
          response = page.expect_response(
            ->(resp) { resp.url.include?(UNITS_API) && resp.status == 200 },
            timeout: 15_000
          ) { navigate_to(path) }

          api_body = JSON.parse(response.body)
          if api_body["data"].is_a?(Array)
            log "Captured #{api_body["data"].length} units from API"
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
