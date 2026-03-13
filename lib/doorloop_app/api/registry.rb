# frozen_string_literal: true

require "json"

module DoorLoopApp
  module Api
    class Registry
      attr_reader :data

      def initialize(path: nil)
        @path = path || DoorLoopApp.configuration.api_registry_path
        @data = load_registry
      end

      def endpoint(name)
        @data.dig("endpoints", name.to_s)
      end

      def auth_config
        @data["auth"] || {}
      end

      def base_url
        @data["base_url"] || DoorLoopApp.configuration.url
      end

      def endpoints
        @data["endpoints"] || {}
      end

      def discovered?
        @data.key?("endpoints") && !endpoints.empty?
      end

      private

      def load_registry
        return {} unless File.exist?(@path)

        JSON.parse(File.read(@path))
      rescue JSON::ParserError => e
        $stderr.puts "Warning: Could not parse api_registry.json: #{e.message}"
        {}
      end
    end
  end
end
