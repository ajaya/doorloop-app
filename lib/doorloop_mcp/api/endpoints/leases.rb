# frozen_string_literal: true

module DoorloopMcp
  module Api
    module Endpoints
      class Leases
        def initialize(client)
          @client = client
          @endpoint = client.registry.endpoint("list_leases")
        end

        def list_all(property_id: nil, status: nil)
          return nil unless @endpoint

          params = @endpoint["query_params"]&.dup || {}
          params["property_id"] = property_id if property_id
          params["status"] = status if status

          data = @client.get(@endpoint["path"], params: params)
          items = extract_items(data)

          items.map do |item|
            {
              tenant: item["tenantName"] || item["tenant"],
              property: item["propertyName"] || item["property"],
              unit: item["unitName"] || item["unit"],
              start_date: item["startDate"] || item["start_date"],
              end_date: item["endDate"] || item["end_date"],
              rent: item["rent"]&.to_s,
              status: item["status"],
              balance: item["balance"]&.to_s
            }
          end
        end

        private

        def extract_items(data)
          data_key = @endpoint&.dig("response_shape", "data_key")
          if data_key && data.is_a?(Hash)
            data[data_key] || []
          elsif data.is_a?(Array)
            data
          else
            data["data"] || data["items"] || []
          end
        end
      end
    end
  end
end
