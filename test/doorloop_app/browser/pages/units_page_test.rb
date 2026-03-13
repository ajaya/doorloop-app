# frozen_string_literal: true

require "test_helper"

class UnitsPageTest < Minitest::Test
  include TestHelpers

  def test_list_all_captures_api_response
    session = build_mock_session(authenticated: true)
    mock_page = session.page

    api_data = {
      "data" => [
        { "unitId" => "unit_1", "unitName" => "Unit 101", "leaseStatus" => "OCCUPIED", "marketRent" => 1200, "property_id" => "prop_123" },
        { "unitId" => "unit_2", "unitName" => "Unit 102", "leaseStatus" => "VACANT", "marketRent" => 1100, "property_id" => "prop_123" }
      ]
    }

    response = mock("api_response")
    response.stubs(:body).returns(JSON.generate(api_data))
    mock_page.stubs(:expect_response).yields.returns(response)

    units_page = DoorLoopApp::Browser::Pages::UnitsPage.new(session)
    result = units_page.list_all(property_id: "prop_123")

    assert_equal 2, result.length
    assert_equal "unit_1", result[0]["unitId"]
    assert_equal "Unit 101", result[0]["unitName"]
    assert_equal "OCCUPIED", result[0]["leaseStatus"]
  end

  def test_list_all_returns_empty_on_api_failure
    session = build_mock_session(authenticated: true)
    mock_page = session.page

    mock_page.stubs(:expect_response).raises(RuntimeError.new("timeout"))

    units_page = DoorLoopApp::Browser::Pages::UnitsPage.new(session)
    result = units_page.list_all(property_id: "prop_123")

    assert_equal [], result
  end

  def test_list_all_without_property_id_iterates_stored_properties
    session = build_mock_session(authenticated: true)
    mock_page = session.page

    # Set up a store with two properties
    db = Sequel.sqlite(":memory:")
    DoorLoopApp::Models::Property.setup!(db)
    DoorLoopApp::Models::Property.upsert_all([
      { "id" => "p1", "name" => "Prop 1" },
      { "id" => "p2", "name" => "Prop 2" }
    ])

    # Each property fetch returns units
    call_count = 0
    mock_page.stubs(:expect_response).with { true }.returns(
      stub(body: JSON.generate({ "data" => [{ "unitId" => "u#{call_count += 1}", "unitName" => "Unit #{call_count}", "property_id" => "p#{call_count}" }] }))
    )

    units_page = DoorLoopApp::Browser::Pages::UnitsPage.new(session)
    result = units_page.list_all

    assert_equal 2, result.length
    assert result.all? { |u| u["unitId"] }
  end

  def test_list_all_without_property_id_falls_back_to_all_units_page
    session = build_mock_session(authenticated: true)
    mock_page = session.page

    # Empty property store
    db = Sequel.sqlite(":memory:")
    DoorLoopApp::Models::Property.setup!(db)

    api_data = { "data" => [{ "id" => "u1", "name" => "Unit A" }] }
    response = mock("api_response")
    response.stubs(:body).returns(JSON.generate(api_data))
    mock_page.stubs(:expect_response).yields.returns(response)

    units_page = DoorLoopApp::Browser::Pages::UnitsPage.new(session)
    result = units_page.list_all

    assert_equal 1, result.length
    assert_equal "u1", result[0]["id"]
  end
end
