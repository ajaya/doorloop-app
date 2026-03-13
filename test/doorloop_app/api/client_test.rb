# frozen_string_literal: true

require "test_helper"
require "faraday"

class ApiClientTest < Minitest::Test
  def setup
    @token_store = DoorLoopApp::Api::TokenStore.new(session_dir: Dir.mktmpdir("doorloop_test"))
    @token_store.update(token: "test_token")

    @registry = mock("registry")
    @registry.stubs(:base_url).returns("https://api.doorloop.com")
    @registry.stubs(:endpoint).returns(nil)
  end

  def test_get_sends_auth_headers
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/api/properties") do |env|
        assert_equal "Bearer test_token", env.request_headers["Authorization"]
        [200, { "Content-Type" => "application/json" }, '{"data": []}']
      end
    end

    client = build_client(stubs)
    result = client.get("/api/properties")
    assert_equal({ "data" => [] }, result)
  end

  def test_post_sends_json_body
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/api/transactions") do |env|
        assert_equal "application/json", env.request_headers["Content-Type"]
        body = JSON.parse(env.body)
        assert_equal "1200.00", body["amount"]
        [201, { "Content-Type" => "application/json" }, '{"id": "tx_123"}']
      end
    end

    client = build_client(stubs)
    result = client.post("/api/transactions", body: { amount: "1200.00" })
    assert_equal({ "id" => "tx_123" }, result)
  end

  def test_raises_authentication_error_on_401
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/api/properties") do
        [401, {}, "Unauthorized"]
      end
    end

    client = build_client(stubs)
    assert_raises(DoorLoopApp::Api::AuthenticationError) do
      client.get("/api/properties")
    end
  end

  def test_raises_error_on_500
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/api/properties") do
        [500, {}, "Internal Server Error"]
      end
    end

    client = build_client(stubs)
    assert_raises(DoorLoopApp::Api::Error) do
      client.get("/api/properties")
    end
  end

  private

  def build_client(stubs)
    # Build the client with a custom connection using test adapter
    client = DoorLoopApp::Api::Client.new(token_store: @token_store, registry: @registry)
    conn = Faraday.new(url: "https://api.doorloop.com") do |f|
      f.adapter :test, stubs
    end
    client.instance_variable_set(:@connection, conn)
    client
  end
end
