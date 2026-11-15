# frozen_string_literal: true

require "test_helper"

class ApiClientTest < Minitest::Test
  def test_uses_the_authenticated_browser_for_get_and_post
    session = mock("session")
    registry = mock("registry")
    session.stubs(:registry).returns(registry)
    session.expects(:request).with(:get, "/api/properties", params: { page: 2 }).returns({ "data" => [{ "id" => "p1" }] })
    session.expects(:request).with(:post, "/api/transactions", body: { amount: "1200.00" }).returns({ "id" => "tx1" })

    client = DoorLoopApp::Api::Client.new(session: session)
    assert_equal "p1", client.get("/api/properties", params: { page: 2 })["data"].first["id"]
    assert_equal "tx1", client.post("/api/transactions", body: { amount: "1200.00" })["id"]
  end
end
