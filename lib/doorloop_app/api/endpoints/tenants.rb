# frozen_string_literal: true

module DoorLoopApp
  module Api
    module Endpoints
      class Tenants
        def initialize(client)
          @client = client
          @endpoint = client.registry.endpoint("list_tenants")
        end

        def list_all
          return nil unless @endpoint

          data = @client.get(@endpoint["path"], params: @endpoint["query_params"] || {})
          items = extract_items(data)

          items.map do |item|
            {
              name: [item["firstName"], item["lastName"]].compact.join(" ").presence || item["name"],
              email: item["email"],
              phone: item["phone"],
              property: item["propertyName"] || item["property"]
            }
          end
        end

        def search(query:)
          return nil unless @endpoint

          params = (@endpoint["query_params"] || {}).merge("search" => query)
          data = @client.get(@endpoint["path"], params: params)
          items = extract_items(data)

          items.map do |item|
            {
              id: item["id"]&.to_s,
              name: [item["firstName"], item["lastName"]].compact.join(" ").presence || item["name"],
              email: item["email"],
              phone: item["phone"],
              property: item["propertyName"] || item["property"]
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
