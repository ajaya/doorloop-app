# frozen_string_literal: true

module DoorLoopApp
  module Api
    # DoorLoop requests always use the authenticated Chrome page. No copied
    # cookies, bearer-token files or separate HTTP client are required.
    class Client
      attr_reader :registry

      def initialize(session:, registry: session.registry)
        @session = session
        @registry = registry
      end

      def get(path, params: {})
        @session.request(:get, path, params: params)
      end

      def post(path, body: {}, params: {})
        options = { body: body }
        options[:params] = params unless params.empty?
        @session.request(:post, path, **options)
      end

      def put(path, body: {})
        @session.request(:put, path, body: body)
      end
    end
  end
end
