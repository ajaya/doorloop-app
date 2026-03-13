# frozen_string_literal: true

module DoorloopMcp
  module Api
    module Endpoints
      class Units
        def initialize(client)
          @client = client
          @endpoint = client.registry.endpoint("list_units")
        end

        def list_all(property_id:)
          return nil unless @endpoint

          path = @endpoint["path"].gsub(":property_id", property_id.to_s)
          params = (@endpoint["query_params"] || {}).merge("property_id" => property_id)
          data = @client.get(path, params: params)
          items = extract_items(data)

          items.map do |item|
            {
              name: item["name"],
              status: item["status"],
              rent: item["rent"]&.to_s || item["marketRent"]&.to_s,
              tenant: item["tenantName"] || item["tenant"]
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
