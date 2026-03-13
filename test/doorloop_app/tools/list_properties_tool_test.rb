# frozen_string_literal: true

require "test_helper"

class ListPropertiesToolTest < Minitest::Test
  include TestHelpers

  def test_returns_properties
    service = mock("service")
    service.expects(:list_properties).with(refresh: false).returns([
      { id: "abc123", name: "Test Property", address: "Oakland, CA, 94607", type: "Multi-Family", units: "4" }
    ])

    server = build_test_server(service: service)
    DoorLoopApp::Tools::ListPropertiesTool.register(server)
    result = call_tool(server, "doorloop_list_properties")

    refute result[:isError]
    parsed = JSON.parse(result[:content].first[:text])
    assert_equal 1, parsed.length
    assert_equal "Test Property", parsed.first["name"]
  end

  def test_returns_empty_message
    service = mock("service")
    service.expects(:list_properties).with(refresh: false).returns([])

    server = build_test_server(service: service)
    DoorLoopApp::Tools::ListPropertiesTool.register(server)
    result = call_tool(server, "doorloop_list_properties")

    refute result[:isError]
    assert_match(/No properties found/, result[:content].first[:text])
  end

  def test_handles_error
    service = mock("service")
    service.expects(:list_properties).with(refresh: false).raises(RuntimeError.new("All strategies failed"))

    server = build_test_server(service: service)
    DoorLoopApp::Tools::ListPropertiesTool.register(server)
    result = call_tool(server, "doorloop_list_properties")

    assert result[:isError]
    assert_match(/Failed to list properties/, result[:content].first[:text])
  end
end
