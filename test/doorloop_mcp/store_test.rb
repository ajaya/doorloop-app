# frozen_string_literal: true

require "test_helper"

class StoreTest < Minitest::Test
  def setup
    @store = DoorloopMcp::Store.new(db_path: ":memory:")
  end

  def test_upsert_and_retrieve_properties
    properties = [
      { id: "abc123", name: "Sunset Apartments", address: "123 Main St", type: "Multi-Family", units: "12" },
      { id: "def456", name: "Oak Villa", address: "456 Oak Ave", type: "Condo", units: "4" }
    ]

    @store.upsert_properties(properties)
    assert_equal 2, @store.properties_count

    all = @store.all_properties
    assert_equal 2, all.length
    assert_equal "Oak Villa", all[0][:name]       # sorted by name
    assert_equal "Sunset Apartments", all[1][:name]
  end

  def test_upsert_updates_existing_by_id
    @store.upsert_properties([{ id: "prop_1", name: "Sunset Apartments", address: "123 Main St" }])
    assert_equal 1, @store.properties_count

    @store.upsert_properties([{ id: "prop_1", name: "Sunset Apartments", address: "789 New St" }])
    assert_equal 1, @store.properties_count

    prop = @store.find_property("prop_1")
    assert_equal "789 New St", prop[:address]
  end

  def test_find_property_by_id
    @store.upsert_properties([{ id: "prop_1", name: "Sunset Apartments" }])
    prop = @store.find_property("prop_1")
    assert_equal "Sunset Apartments", prop[:name]
  end

  def test_find_property_by_name
    @store.upsert_properties([
      { id: "p1", name: "Sunset Apartments", address: "123 Main St" },
      { id: "p2", name: "Sunrise Condos", address: "456 Oak Ave" }
    ])

    results = @store.find_property_by_name("sunset")
    assert_equal 1, results.length
    assert_equal "Sunset Apartments", results.first[:name]
  end

  def test_properties_stale
    assert @store.properties_stale?, "Empty store should be stale"

    @store.upsert_properties([{ id: "p1", name: "Test Property" }])
    refute @store.properties_stale?(max_age: 300), "Just inserted should not be stale"
    assert @store.properties_stale?(max_age: 0), "With 0 max_age everything is stale"
  end

  def test_clear_properties
    @store.upsert_properties([{ id: "p1", name: "Test" }])
    assert_equal 1, @store.properties_count

    @store.clear_properties
    assert_equal 0, @store.properties_count
  end

  def test_upsert_with_string_keys
    properties = [{ "id" => "p1", "name" => "String Keys Property", "address" => "100 Test St" }]
    @store.upsert_properties(properties)
    assert_equal 1, @store.properties_count
    assert_equal "String Keys Property", @store.all_properties.first[:name]
  end

  def test_stores_full_json_data
    properties = [{
      id: "prop_123",
      name: "Test Property",
      address: "100 Test St",
      type: "Multi-Family",
      units: "12",
      extra_field: "preserved"
    }]
    @store.upsert_properties(properties)

    prop = @store.find_property("prop_123")
    assert_equal "Test Property", prop[:name]
    assert_equal "preserved", prop[:extra_field]
  end

  def test_extracts_columns_from_json
    properties = [{
      "id" => "prop_1",
      "name" => "Sunset Apartments",
      "address" => { "street1" => "123 Main St", "city" => "Oakland", "state" => "CA", "zip" => "94607" },
      "type" => "RESIDENTIAL_MULTI_FAMILY",
      "numActiveUnits" => 12
    }]
    @store.upsert_properties(properties)

    # Verify extracted columns exist in the raw DB row
    row = @store.db[:properties].where(id: "prop_1").first
    assert_equal "Sunset Apartments", row[:name]
    assert_equal "123 Main St, Oakland, CA, 94607", row[:address]
    assert_equal "RESIDENTIAL_MULTI_FAMILY", row[:property_type]
    assert_equal "12", row[:units_count]
  end

  def test_skips_properties_without_id
    properties = [
      { id: "p1", name: "Has ID" },
      { name: "No ID" }
    ]
    @store.upsert_properties(properties)
    assert_equal 1, @store.properties_count
  end

  def test_stored_at_timestamp
    @store.upsert_properties([{ id: "p1", name: "Test" }])
    prop = @store.all_properties.first
    assert prop[:_stored_at], "Should have _stored_at timestamp"
  end

  def test_model_direct_access
    @store.upsert_properties([{ id: "p1", name: "Direct" }])
    prop = DoorloopMcp::Models::Property["p1"]
    assert_equal "Direct", prop.name
    assert_equal "p1", prop.id
  end
end
