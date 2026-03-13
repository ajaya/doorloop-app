# frozen_string_literal: true

require "test_helper"

class ListTenantsToolTest < Minitest::Test
  include TestHelpers

  def test_returns_tenants
    service = mock("service")
    service.expects(:list_tenants).with(property_id: nil, refresh: false).returns([
      { name: "John Doe", email: "john@example.com", phone: "555-0100", property: "Test Property" }
    ])

    server = build_test_server(service: service)
    DoorLoopApp::Tools::ListTenantsTool.register(server)
    result = call_tool(server, "doorloop_list_tenants")

    refute result[:isError]
    parsed = JSON.parse(result[:content].first[:text])
    assert_equal 1, parsed.length
    assert_equal "John Doe", parsed.first["name"]
  end

  def test_returns_empty_message
    service = mock("service")
    service.expects(:list_tenants).with(property_id: nil, refresh: false).returns([])

    server = build_test_server(service: service)
    DoorLoopApp::Tools::ListTenantsTool.register(server)
    result = call_tool(server, "doorloop_list_tenants")

    refute result[:isError]
    assert_match(/No tenants found/, result[:content].first[:text])
  end

  def test_handles_error
    service = mock("service")
    service.expects(:list_tenants).with(property_id: nil, refresh: false).raises(RuntimeError.new("All strategies failed"))

    server = build_test_server(service: service)
    DoorLoopApp::Tools::ListTenantsTool.register(server)
    result = call_tool(server, "doorloop_list_tenants")

    assert result[:isError]
    assert_match(/Failed to list tenants/, result[:content].first[:text])
  end
end
