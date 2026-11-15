# frozen_string_literal: true

module DoorLoopApp
  module Browser
    Response = ::Data.define(:url, :status, :body, :headers, :method, :request_body) do
      def initialize(url:, status:, body:, headers:, method:, request_body: nil)
        super(url:, status:, body:, headers:, method:, request_body:)
      end
    end
  end
end
