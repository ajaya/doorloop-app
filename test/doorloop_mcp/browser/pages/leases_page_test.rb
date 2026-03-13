# frozen_string_literal: true

require "test_helper"

class LeasesPageTest < Minitest::Test
  include TestHelpers

  def test_list_all_captures_api_response
    session = build_mock_session(authenticated: true)
    mock_page = session.page

    api_data = {
      "data" => [
        { "id" => "l1", "name" => "John Doe", "property" => "p1", "status" => "ACTIVE",
          "start" => "2025-12-01", "end" => "2026-11-30", "totalRecurringRent" => 1800 },
        { "id" => "l2", "name" => "Jane Smith", "property" => "p1", "status" => "ACTIVE",
          "start" => "2026-03-01", "end" => "2027-02-28", "totalRecurringRent" => 2850 }
      ]
    }

    response = mock("api_response")
    response.stubs(:body).returns(JSON.generate(api_data))
    mock_page.stubs(:expect_response).yields.returns(response)

    leases_page = DoorloopMcp::Browser::Pages::LeasesPage.new(session)
    result = leases_page.list_all

    assert_equal 2, result.length
    assert_equal "l1", result[0]["id"]
    assert_equal "John Doe", result[0]["name"]
    assert_equal "ACTIVE", result[0]["status"]
  end

  def test_list_all_ignores_property_id
    session = build_mock_session(authenticated: true)
    mock_page = session.page

    api_data = { "data" => [{ "id" => "l1", "name" => "Lease A", "property" => "p1" }] }
    response = mock("api_response")
    response.stubs(:body).returns(JSON.generate(api_data))
    mock_page.stubs(:expect_response).yields.returns(response)

    leases_page = DoorloopMcp::Browser::Pages::LeasesPage.new(session)
    result = leases_page.list_all(property_id: "p1")

    assert_equal 1, result.length
    assert_equal "l1", result[0]["id"]
  end

  def test_list_all_returns_empty_on_api_failure
    session = build_mock_session(authenticated: true)
    mock_page = session.page

    mock_page.stubs(:expect_response).raises(RuntimeError.new("timeout"))

    leases_page = DoorloopMcp::Browser::Pages::LeasesPage.new(session)
    result = leases_page.list_all

    assert_equal [], result
  end
end
