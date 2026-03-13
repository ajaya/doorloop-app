# frozen_string_literal: true

module DoorLoopApp
  module Api
    module Endpoints
      class Properties
        def initialize(client)
          @client = client
          @endpoint = client.registry.endpoint("list_properties")
        end

        def list_all
          return nil unless @endpoint

          data = @client.get(@endpoint["path"], params: @endpoint["query_params"] || {})
          items = extract_items(data)

          items.map do |item|
            {
              id: item["id"]&.to_s,
              name: item["name"],
              address: format_address(item),
              type: item["type"],
              units: item["unitCount"]&.to_s || item["units"]&.to_s
            }
          end
        end

        private

        def extract_items(data)
          data_key = @endpoint.dig("response_shape", "data_key")
          if data_key && data.is_a?(Hash)
            data[data_key] || []
          elsif data.is_a?(Array)
            data
          else
            data["data"] || data["items"] || []
          end
        end

        def format_address(item)
          parts = [item["address"], item["city"], item["state"], item["zip"]].compact
          parts.any? ? parts.join(", ") : item["address"]
        end
      end
    end
  end
end
