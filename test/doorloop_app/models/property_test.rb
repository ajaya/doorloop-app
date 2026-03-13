# frozen_string_literal: true

require "test_helper"

class PropertyModelTest < Minitest::Test
  def setup
    @db = Sequel.sqlite(":memory:")
    DoorLoopApp::Models::Property.setup!(@db)
  end

  def test_upsert_and_find
    DoorLoopApp::Models::Property.upsert_all([
      { "id" => "p1", "name" => "Sunset Apartments", "type" => "RESIDENTIAL_MULTI_FAMILY" }
    ])

    prop = DoorLoopApp::Models::Property["p1"]
    assert_equal "Sunset Apartments", prop.name
    assert_equal "RESIDENTIAL_MULTI_FAMILY", prop.to_api[:type]
  end

  def test_extracts_columns
    DoorLoopApp::Models::Property.upsert_all([{
      "id" => "p1",
      "name" => "Test",
      "address" => { "street1" => "123 Main", "city" => "Oakland", "state" => "CA", "zip" => "94607" },
      "type" => "CONDO",
      "numActiveUnits" => 4
    }])

    row = @db[:properties].where(id: "p1").first
    assert_equal "Test", row[:name]
    assert_equal "123 Main, Oakland, CA, 94607", row[:address]
    assert_equal "CONDO", row[:property_type]
    assert_equal "4", row[:units_count]
  end

  def test_upsert_updates_existing
    DoorLoopApp::Models::Property.upsert_all([{ id: "p1", name: "Old Name" }])
    DoorLoopApp::Models::Property.upsert_all([{ id: "p1", name: "New Name" }])

    assert_equal 1, DoorLoopApp::Models::Property.count
    assert_equal "New Name", DoorLoopApp::Models::Property["p1"].name
  end

  def test_find_by_name
    DoorLoopApp::Models::Property.upsert_all([
      { id: "p1", name: "Sunset Apartments" },
      { id: "p2", name: "Sunrise Condos" }
    ])

    results = DoorLoopApp::Models::Property.find_by_name("sunset")
    assert_equal 1, results.length
    assert_equal "Sunset Apartments", results.first.name
  end

  def test_stale
    assert DoorLoopApp::Models::Property.stale?
    DoorLoopApp::Models::Property.upsert_all([{ id: "p1", name: "Test" }])
    refute DoorLoopApp::Models::Property.stale?(max_age: 300)
    assert DoorLoopApp::Models::Property.stale?(max_age: 0)
  end

  def test_preserves_full_json
    DoorLoopApp::Models::Property.upsert_all([{
      id: "p1", name: "Test", custom_field: "preserved"
    }])

    prop = DoorLoopApp::Models::Property["p1"]
    assert_equal "preserved", prop.to_api[:custom_field]
  end

  def test_skips_without_id
    DoorLoopApp::Models::Property.upsert_all([
      { id: "p1", name: "Has ID" },
      { name: "No ID" }
    ])
    assert_equal 1, DoorLoopApp::Models::Property.count
  end

  def test_clear
    DoorLoopApp::Models::Property.upsert_all([{ id: "p1", name: "Test" }])
    DoorLoopApp::Models::Property.clear!
    assert_equal 0, DoorLoopApp::Models::Property.count
  end
end
