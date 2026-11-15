# frozen_string_literal: true

module DoorLoopApp
  module Api
    module Endpoints
      class Base
        def initialize(client)
          @client = client
          @endpoint = client.registry.endpoint(self.class::OPERATION)
        end

        private

        def fetch(params: {}, omit: [])
          return nil unless @endpoint

          query = (@endpoint["query_params"] || {}).reject { |key, _| omit.include?(key) }
          data = @client.get(@endpoint.fetch("path"), params: query.merge(params))
          return data if data.is_a?(Array)

          key = @endpoint.dig("response_shape", "data_key") || "data"
          items = data.is_a?(Hash) && (data[key] || data["items"])
          raise Error, "Unexpected API response shape" unless items.is_a?(Array)

          items # Keep every field, including IDs, lease links and nested data.
        end
      end
    end
  end
end
