# frozen_string_literal: true

require "test_helper"

class ListUnitsToolTest < Minitest::Test
  include TestHelpers

  def test_returns_units
    service = mock("service")
    service.expects(:list_units).with(property_id: "prop_123", refresh: false).returns([
      { name: "Unit 101", status: "Occupied", rent: "$1,200", tenant: "John Doe" }
    ])

    server = build_test_server(service: service)
    DoorLoopApp::Tools::ListUnitsTool.register(server)
    result = call_tool(server, "doorloop_list_units", { "property_id" => "prop_123" })

    refute result[:isError]
    parsed = JSON.parse(result[:content].first[:text])
    assert_equal 1, parsed.length
    assert_equal "Unit 101", parsed.first["name"]
  end

  def test_returns_empty_message
    service = mock("service")
    service.expects(:list_units).with(property_id: "prop_123", refresh: false).returns([])

    server = build_test_server(service: service)
    DoorLoopApp::Tools::ListUnitsTool.register(server)
    result = call_tool(server, "doorloop_list_units", { "property_id" => "prop_123" })

    refute result[:isError]
    assert_match(/No units found/, result[:content].first[:text])
  end

  def test_handles_error
    service = mock("service")
    service.expects(:list_units).with(property_id: "prop_123", refresh: false).raises(RuntimeError.new("All strategies failed"))

    server = build_test_server(service: service)
    DoorLoopApp::Tools::ListUnitsTool.register(server)
    result = call_tool(server, "doorloop_list_units", { "property_id" => "prop_123" })

    assert result[:isError]
    assert_match(/Failed to list units/, result[:content].first[:text])
  end
end
