# frozen_string_literal: true

require "test_helper"

class LeaseModelTest < Minitest::Test
  def setup
    @db = Sequel.sqlite(":memory:")
    DoorLoopApp::Models::Lease.setup!(@db)
  end

  def test_upsert_and_find
    DoorLoopApp::Models::Lease.upsert_all([
      { "id" => "l1", "name" => "John Doe", "property" => "p1", "status" => "ACTIVE",
        "start" => "2025-12-01", "end" => "2026-11-30", "totalRecurringRent" => 1800,
        "totalBalanceDue" => 425, "outstandingBalance" => 425, "overdueBalance" => 425 }
    ])

    lease = DoorLoopApp::Models::Lease["l1"]
    assert_equal "John Doe", lease.name
    assert_equal "p1", lease.property_id
    assert_equal "ACTIVE", lease.status
  end

  def test_extracts_columns
    DoorLoopApp::Models::Lease.upsert_all([{
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
    DoorLoopApp::Models::Lease.upsert_all([
      { "id" => "l1", "name" => "Alice", "property" => "p1", "status" => "ACTIVE" },
      { "id" => "l2", "name" => "Bob", "property" => "p1", "status" => "ACTIVE" },
      { "id" => "l3", "name" => "Charlie", "property" => "p2", "status" => "ACTIVE" }
    ])

    leases = DoorLoopApp::Models::Lease.for_property("p1")
    assert_equal 2, leases.length
    assert_equal "Alice", leases[0].name
    assert_equal "Bob", leases[1].name
  end

  def test_active
    DoorLoopApp::Models::Lease.upsert_all([
      { "id" => "l1", "name" => "Active Lease", "property" => "p1", "status" => "ACTIVE" },
      { "id" => "l2", "name" => "Expired Lease", "property" => "p1", "status" => "EXPIRED" }
    ])

    active = DoorLoopApp::Models::Lease.active
    assert_equal 1, active.length
    assert_equal "Active Lease", active.first.name
  end

  def test_upsert_updates_existing
    DoorLoopApp::Models::Lease.upsert_all([{ "id" => "l1", "name" => "Old", "property" => "p1" }])
    DoorLoopApp::Models::Lease.upsert_all([{ "id" => "l1", "name" => "New", "property" => "p1" }])

    assert_equal 1, DoorLoopApp::Models::Lease.count
    assert_equal "New", DoorLoopApp::Models::Lease["l1"].name
  end

  def test_preserves_full_json
    DoorLoopApp::Models::Lease.upsert_all([{
      "id" => "l1", "name" => "Test", "property" => "p1",
      "renewalInfo" => { "renewalStage" => "NOT_STARTED" }
    }])

    lease = DoorLoopApp::Models::Lease["l1"]
    api = lease.to_api
    assert_equal "NOT_STARTED", api[:renewalInfo][:renewalStage]
  end

  def test_skips_without_id
    DoorLoopApp::Models::Lease.upsert_all([
      { "id" => "l1", "name" => "Has ID" },
      { "name" => "No ID" }
    ])
    assert_equal 1, DoorLoopApp::Models::Lease.count
  end

  def test_clear
    DoorLoopApp::Models::Lease.upsert_all([{ "id" => "l1", "name" => "Test" }])
    DoorLoopApp::Models::Lease.clear!
    assert_equal 0, DoorLoopApp::Models::Lease.count
  end
end
