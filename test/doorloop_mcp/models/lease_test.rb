# frozen_string_literal: true

require "test_helper"

class LeaseModelTest < Minitest::Test
  def setup
    @db = Sequel.sqlite(":memory:")
    DoorloopMcp::Models::Lease.setup!(@db)
  end

  def test_upsert_and_find
    DoorloopMcp::Models::Lease.upsert_all([
      { "id" => "l1", "name" => "John Doe", "property" => "p1", "status" => "ACTIVE",
        "start" => "2025-12-01", "end" => "2026-11-30", "totalRecurringRent" => 1800,
        "totalBalanceDue" => 425, "outstandingBalance" => 425, "overdueBalance" => 425 }
    ])

    lease = DoorloopMcp::Models::Lease["l1"]
    assert_equal "John Doe", lease.name
    assert_equal "p1", lease.property_id
    assert_equal "ACTIVE", lease.status
  end

  def test_extracts_columns
    DoorloopMcp::Models::Lease.upsert_all([{
      "id" => "l1", "name" => "John Doe", "property" => "p1",
      "units" => ["unit_abc", "unit_def"],
      "status" => "ACTIVE",
      "start" => "2025-12-01", "end" => "2026-11-30", "totalRecurringRent" => 1800,
      "totalBalanceDue" => 425, "outstandingBalance" => 425, "overdueBalance" => 200
    }])

    row = @db[:leases].where(id: "l1").first
    assert_equal "John Doe", row[:name]
    assert_equal "p1", row[:property_id]
    assert_equal '["unit_abc","unit_def"]', row[:unit_ids]
    assert_equal "ACTIVE", row[:status]
    assert_equal "2025-12-01", row[:start_date]
    assert_equal "2026-11-30", row[:end_date]
    assert_equal "1800", row[:total_rent]
    assert_equal "425", row[:balance]
    assert_equal "425", row[:outstanding_balance]
    assert_equal "200", row[:overdue_balance]
  end

  def test_for_property
    DoorloopMcp::Models::Lease.upsert_all([
      { "id" => "l1", "name" => "Alice", "property" => "p1", "status" => "ACTIVE" },
      { "id" => "l2", "name" => "Bob", "property" => "p1", "status" => "ACTIVE" },
      { "id" => "l3", "name" => "Charlie", "property" => "p2", "status" => "ACTIVE" }
    ])

    leases = DoorloopMcp::Models::Lease.for_property("p1")
    assert_equal 2, leases.length
    assert_equal "Alice", leases[0].name
    assert_equal "Bob", leases[1].name
  end

  def test_active
    DoorloopMcp::Models::Lease.upsert_all([
      { "id" => "l1", "name" => "Active Lease", "property" => "p1", "status" => "ACTIVE" },
      { "id" => "l2", "name" => "Expired Lease", "property" => "p1", "status" => "EXPIRED" }
    ])

    active = DoorloopMcp::Models::Lease.active
    assert_equal 1, active.length
    assert_equal "Active Lease", active.first.name
  end

  def test_upsert_updates_existing
    DoorloopMcp::Models::Lease.upsert_all([{ "id" => "l1", "name" => "Old", "property" => "p1" }])
    DoorloopMcp::Models::Lease.upsert_all([{ "id" => "l1", "name" => "New", "property" => "p1" }])

    assert_equal 1, DoorloopMcp::Models::Lease.count
    assert_equal "New", DoorloopMcp::Models::Lease["l1"].name
  end

  def test_preserves_full_json
    DoorloopMcp::Models::Lease.upsert_all([{
      "id" => "l1", "name" => "Test", "property" => "p1",
      "renewalInfo" => { "renewalStage" => "NOT_STARTED" }
    }])

    lease = DoorloopMcp::Models::Lease["l1"]
    api = lease.to_api
    assert_equal "NOT_STARTED", api[:renewalInfo][:renewalStage]
  end

  def test_skips_without_id
    DoorloopMcp::Models::Lease.upsert_all([
      { "id" => "l1", "name" => "Has ID" },
      { "name" => "No ID" }
    ])
    assert_equal 1, DoorloopMcp::Models::Lease.count
  end

  def test_clear
    DoorloopMcp::Models::Lease.upsert_all([{ "id" => "l1", "name" => "Test" }])
    DoorloopMcp::Models::Lease.clear!
    assert_equal 0, DoorloopMcp::Models::Lease.count
  end
end
