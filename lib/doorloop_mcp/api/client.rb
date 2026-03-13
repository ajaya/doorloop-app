# frozen_string_literal: true

require "faraday"
require "json"

module DoorloopMcp
  module Api
    class Client
      attr_reader :token_store, :registry

      def initialize(token_store:, registry: nil)
        @token_store = token_store
        @registry = registry || Registry.new
        @connection = build_connection
      end

      def get(path, params: {})
        request(:get, path, params: params)
      end

      def post(path, body: {})
        request(:post, path, body: body)
      end

      def put(path, body: {})
        request(:put, path, body: body)
      end

      private

      def request(method, path, params: {}, body: nil)
        response = @connection.send(method) do |req|
          req.url path
          req.params = params if params.any?
          req.body = body.to_json if body
          req.headers.merge!(token_store.auth_headers)
          req.headers["Content-Type"] = "application/json" if body
        end

        raise AuthenticationError, "Token expired (401)" if response.status == 401
        raise Error, "API error #{response.status}: #{response.body}" unless response.success?

        JSON.parse(response.body)
      rescue JSON::ParserError
        raise Error, "Invalid JSON response: #{response.body[0..200]}"
      end

      def build_connection
        Faraday.new(url: registry.base_url) do |f|
          f.response :logger, $stderr, bodies: false if ENV["DOORLOOP_DEBUG"]
          f.adapter Faraday.default_adapter
          f.options.timeout = 30
          f.options.open_timeout = 10
        end
      end
    end
  end
end
