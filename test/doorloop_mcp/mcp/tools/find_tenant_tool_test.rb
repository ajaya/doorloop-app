# frozen_string_literal: true

require "test_helper"

class FindTenantToolTest < Minitest::Test
  include TestHelpers

  def test_returns_matching_tenants
    service = mock("service")
    service.expects(:find_tenant).with("John", refresh: false).returns([
      { name: "John Doe", email: "john@example.com", phone: "555-0100", property: "Oak Apts" }
    ])

    server = build_test_server(service: service)
    DoorloopMcp::MCP::Tools::FindTenantTool.register(server)
    result = call_tool(server, "doorloop_find_tenant", { "query" => "John" })

    refute result[:isError]
    parsed = JSON.parse(result[:content].first[:text])
    assert_equal "John Doe", parsed.first["name"]
  end

  def test_returns_empty_message
    service = mock("service")
    service.expects(:find_tenant).with("Nobody", refresh: false).returns([])

    server = build_test_server(service: service)
    DoorloopMcp::MCP::Tools::FindTenantTool.register(server)
    result = call_tool(server, "doorloop_find_tenant", { "query" => "Nobody" })

    refute result[:isError]
    assert_match(/No tenants found matching 'Nobody'/, result[:content].first[:text])
  end

  def test_handles_error
    service = mock("service")
    service.expects(:find_tenant).with("test", refresh: false).raises(RuntimeError.new("fail"))

    server = build_test_server(service: service)
    DoorloopMcp::MCP::Tools::FindTenantTool.register(server)
    result = call_tool(server, "doorloop_find_tenant", { "query" => "test" })

    assert result[:isError]
    assert_match(/Failed to find tenant/, result[:content].first[:text])
  end
end
