# frozen_string_literal: true

require "test_helper"

class ApiEndpointsPropertiesTest < Minitest::Test
  def test_list_all_maps_api_response
    endpoint_config = {
      "path" => "/api/properties",
      "query_params" => {},
      "response_shape" => { "data_key" => "data" }
    }

    registry = mock("registry")
    registry.stubs(:endpoint).with("list_properties").returns(endpoint_config)

    client = mock("api_client")
    client.stubs(:registry).returns(registry)
    client.expects(:get).with("/api/properties", params: {}).returns({
      "data" => [
        { "id" => 123, "name" => "Oak Apartments", "address" => "123 Oak St", "city" => "Oakland", "state" => "CA", "zip" => "94607", "type" => "Multi-Family", "unitCount" => 4 }
      ]
    })

    properties = DoorloopMcp::Api::Endpoints::Properties.new(client)
    result = properties.list_all

    assert_equal 1, result.length
    assert_equal "123", result.first[:id]
    assert_equal "Oak Apartments", result.first[:name]
    assert_equal "123 Oak St, Oakland, CA, 94607", result.first[:address]
    assert_equal "Multi-Family", result.first[:type]
    assert_equal "4", result.first[:units]
  end

  def test_returns_nil_when_no_endpoint_configured
    registry = mock("registry")
    registry.stubs(:endpoint).with("list_properties").returns(nil)

    client = mock("api_client")
    client.stubs(:registry).returns(registry)

    properties = DoorloopMcp::Api::Endpoints::Properties.new(client)
    assert_nil properties.list_all
  end
end
