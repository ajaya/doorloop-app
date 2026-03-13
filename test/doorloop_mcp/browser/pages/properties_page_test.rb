# frozen_string_literal: true

require "test_helper"

class PropertiesPageTest < Minitest::Test
  include TestHelpers

  def test_list_all_captures_api_response
    session = build_mock_session(authenticated: true)
    mock_page = session.page

    api_data = {
      "data" => [
        { "id" => "abc123", "name" => "Oakland Heights", "address" => { "street1" => "123 Main St", "city" => "Oakland", "state" => "CA", "zip" => "94607" }, "type" => "Multi-Family", "totalUnits" => 4 }
      ]
    }

    response = mock("api_response")
    response.stubs(:body).returns(JSON.generate(api_data))

    mock_page.stubs(:expect_response).yields.returns(response)

    properties_page = DoorloopMcp::Browser::Pages::PropertiesPage.new(session)
    result = properties_page.list_all

    assert_equal 1, result.length
    assert_equal "abc123", result.first["id"]
    assert_equal "Oakland Heights", result.first["name"]
    assert_equal "Multi-Family", result.first["type"]
  end

  def test_list_all_returns_empty_on_api_failure
    session = build_mock_session(authenticated: true)
    mock_page = session.page

    mock_page.stubs(:expect_response).raises(RuntimeError.new("timeout"))

    properties_page = DoorloopMcp::Browser::Pages::PropertiesPage.new(session)
    result = properties_page.list_all

    assert_equal [], result
  end

  def test_list_all_filters_items_without_id
    session = build_mock_session(authenticated: true)
    mock_page = session.page

    api_data = {
      "data" => [
        { "id" => "abc123", "name" => "Valid Property" },
        { "name" => "No ID Property" }
      ]
    }

    response = mock("api_response")
    response.stubs(:body).returns(JSON.generate(api_data))
    mock_page.stubs(:expect_response).yields.returns(response)

    properties_page = DoorloopMcp::Browser::Pages::PropertiesPage.new(session)
    result = properties_page.list_all

    assert_equal 1, result.length
    assert_equal "abc123", result.first["id"]
  end
end
