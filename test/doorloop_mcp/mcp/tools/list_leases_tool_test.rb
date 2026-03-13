# frozen_string_literal: true

require "test_helper"

class ListLeasesToolTest < Minitest::Test
  include TestHelpers

  def test_returns_leases
    service = mock("service")
    service.expects(:list_leases).with(property_id: nil, refresh: false).returns([
      { tenant: "Jane Smith", property: "Oak Apartments", unit: "2B", start_date: "01/01/2026",
        end_date: "12/31/2026", rent: "$1,500", status: "Active", balance: "$0.00" }
    ])

    server = build_test_server(service: service)
    DoorloopMcp::MCP::Tools::ListLeasesTool.register(server)
    result = call_tool(server, "doorloop_list_leases")

    refute result[:isError]
    parsed = JSON.parse(result[:content].first[:text])
    assert_equal 1, parsed.length
    assert_equal "Jane Smith", parsed.first["tenant"]
  end

  def test_returns_leases_with_property_filter
    service = mock("service")
    service.expects(:list_leases).with(property_id: "prop_123", refresh: false).returns([
      { tenant: "Jane Smith", property: "Oak Apartments", unit: "2B", start_date: "01/01/2026",
        end_date: "12/31/2026", rent: "$1,500", status: "Active", balance: "$0.00" }
    ])

    server = build_test_server(service: service)
    DoorloopMcp::MCP::Tools::ListLeasesTool.register(server)
    result = call_tool(server, "doorloop_list_leases", { "property_id" => "prop_123" })

    refute result[:isError]
    parsed = JSON.parse(result[:content].first[:text])
    assert_equal 1, parsed.length
  end

  def test_returns_empty_message
    service = mock("service")
    service.expects(:list_leases).with(property_id: nil, refresh: false).returns([])

    server = build_test_server(service: service)
    DoorloopMcp::MCP::Tools::ListLeasesTool.register(server)
    result = call_tool(server, "doorloop_list_leases")

    refute result[:isError]
    assert_match(/No leases found/, result[:content].first[:text])
  end

  def test_handles_error
    service = mock("service")
    service.expects(:list_leases).with(property_id: nil, refresh: false).raises(RuntimeError.new("All strategies failed"))

    server = build_test_server(service: service)
    DoorloopMcp::MCP::Tools::ListLeasesTool.register(server)
    result = call_tool(server, "doorloop_list_leases")

    assert result[:isError]
    assert_match(/Failed to list leases/, result[:content].first[:text])
  end
end
