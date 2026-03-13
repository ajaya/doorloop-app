# frozen_string_literal: true

require "test_helper"

class TenantsPageTest < Minitest::Test
  include TestHelpers

  def test_list_all_captures_api_response
    session = build_mock_session(authenticated: true)
    mock_page = session.page

    api_data = {
      "data" => [
        { "id" => "t1", "name" => "John Doe",
          "tenant" => { "firstName" => "John", "lastName" => "Doe",
                        "emails" => [{ "address" => "john@example.com" }],
                        "phones" => [{ "number" => "555-0100" }] },
          "property" => "p1", "lease" => "l1", "units" => ["u1"],
          "status" => "CURRENT", "balanceDue" => 0 },
        { "id" => "t2", "name" => "Jane Smith",
          "tenant" => { "firstName" => "Jane", "lastName" => "Smith",
                        "emails" => [{ "address" => "jane@example.com" }] },
          "property" => "p1", "lease" => "l2", "units" => ["u2"],
          "status" => "CURRENT", "balanceDue" => 425 }
      ]
    }

    response = mock("api_response")
    response.stubs(:body).returns(JSON.generate(api_data))
    mock_page.stubs(:expect_response).yields.returns(response)

    tenants_page = DoorLoopApp::Browser::Pages::TenantsPage.new(session)
    result = tenants_page.list_all

    assert_equal 2, result.length
    assert_equal "t1", result[0]["id"]
    assert_equal "John Doe", result[0]["name"]
    assert_equal "CURRENT", result[0]["status"]
  end

  def test_list_all_returns_empty_on_api_failure
    session = build_mock_session(authenticated: true)
    mock_page = session.page

    mock_page.stubs(:expect_response).raises(RuntimeError.new("timeout"))

    tenants_page = DoorLoopApp::Browser::Pages::TenantsPage.new(session)
    result = tenants_page.list_all

    assert_equal [], result
  end
end
