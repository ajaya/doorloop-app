# frozen_string_literal: true

require "test_helper"

class UnitModelTest < Minitest::Test
  def setup
    @db = Sequel.sqlite(":memory:")
    DoorloopMcp::Models::Unit.setup!(@db)
  end

  def test_upsert_and_find
    DoorloopMcp::Models::Unit.upsert_all([
      { "unitId" => "u1", "unitName" => "Unit 101", "property" => "p1", "leaseStatus" => "OCCUPIED", "marketRent" => 1200 }
    ])

    unit = DoorloopMcp::Models::Unit["u1"]
    assert_equal "Unit 101", unit.name
    assert_equal "p1", unit.property_id
    assert_equal "Unit 101", unit.to_api[:unitName]
  end

  def test_extracts_columns
    DoorloopMcp::Models::Unit.upsert_all([{
      "unitId" => "u1", "unitName" => "Unit 101", "property" => "p1",
      "leaseStatus" => "VACANT", "marketRent" => 1500
    }])

    row = @db[:units].where(id: "u1").first
    assert_equal "Unit 101", row[:name]
    assert_equal "p1", row[:property_id]
    assert_equal "VACANT", row[:status]
    assert_equal "1500", row[:rent]
  end

  def test_for_property
    DoorloopMcp::Models::Unit.upsert_all([
      { "unitId" => "u1", "unitName" => "Unit A", "property" => "p1" },
      { "unitId" => "u2", "unitName" => "Unit B", "property" => "p1" },
      { "unitId" => "u3", "unitName" => "Unit C", "property" => "p2" }
    ])

    units = DoorloopMcp::Models::Unit.for_property("p1")
    assert_equal 2, units.length
    assert_equal "Unit A", units[0].name
    assert_equal "Unit B", units[1].name
  end

  def test_upsert_updates_existing
    DoorloopMcp::Models::Unit.upsert_all([{ "unitId" => "u1", "unitName" => "Old", "property" => "p1" }])
    DoorloopMcp::Models::Unit.upsert_all([{ "unitId" => "u1", "unitName" => "New", "property" => "p1" }])

    assert_equal 1, DoorloopMcp::Models::Unit.count
    assert_equal "New", DoorloopMcp::Models::Unit["u1"].name
  end

  def test_preserves_full_json
    DoorloopMcp::Models::Unit.upsert_all([{
      "unitId" => "u1", "unitName" => "Unit 101", "property" => "p1", "custom" => "preserved"
    }])

    unit = DoorloopMcp::Models::Unit["u1"]
    assert_equal "preserved", unit.to_api[:custom]
  end

  def test_skips_without_id
    DoorloopMcp::Models::Unit.upsert_all([
      { "unitId" => "u1", "unitName" => "Has ID" },
      { "unitName" => "No ID" }
    ])
    assert_equal 1, DoorloopMcp::Models::Unit.count
  end

  def test_clear
    DoorloopMcp::Models::Unit.upsert_all([{ "unitId" => "u1", "unitName" => "Test" }])
    DoorloopMcp::Models::Unit.clear!
    assert_equal 0, DoorloopMcp::Models::Unit.count
  end
end
