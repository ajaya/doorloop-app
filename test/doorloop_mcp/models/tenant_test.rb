# frozen_string_literal: true

require "test_helper"

class TenantModelTest < Minitest::Test
  def setup
    @db = Sequel.sqlite(":memory:")
    DoorloopMcp::Models::Tenant.setup!(@db)
  end

  def test_upsert_and_find
    DoorloopMcp::Models::Tenant.upsert_all([
      { "id" => "t1", "name" => "John Doe",
        "tenant" => {
          "firstName" => "John", "lastName" => "Doe",
          "emails" => [{ "type" => "Primary", "address" => "john@example.com" }],
          "phones" => [{ "type" => "Mobile", "number" => "555-0100" }]
        },
        "property" => "p1", "lease" => "l1", "units" => ["u1"],
        "status" => "CURRENT", "moveInAt" => "2025-01-01", "balanceDue" => 0 }
    ])

    tenant = DoorloopMcp::Models::Tenant["t1"]
    assert_equal "John Doe", tenant.name
    assert_equal "John", tenant.first_name
    assert_equal "Doe", tenant.last_name
    assert_equal "john@example.com", tenant.email
    assert_equal "555-0100", tenant.phone
    assert_equal "p1", tenant.property_id
    assert_equal "l1", tenant.lease_id
    assert_equal "CURRENT", tenant.status
    assert_equal "2025-01-01", tenant.move_in_at
    assert_equal "0", tenant.balance_due
  end

  def test_extracts_columns
    DoorloopMcp::Models::Tenant.upsert_all([{
      "id" => "t1", "name" => "Jane Smith",
      "tenant" => {
        "firstName" => "Jane", "lastName" => "Smith",
        "emails" => [{ "type" => "Primary", "address" => "jane@example.com" }],
        "phones" => [{ "type" => "Mobile", "number" => "555-0200" }]
      },
      "property" => "p2", "lease" => "l2", "units" => ["u1", "u2"],
      "status" => "CURRENT", "moveInAt" => "2025-06-01", "balanceDue" => 425
    }])

    row = @db[:tenants].where(id: "t1").first
    assert_equal "Jane Smith", row[:name]
    assert_equal "Jane", row[:first_name]
    assert_equal "Smith", row[:last_name]
    assert_equal "jane@example.com", row[:email]
    assert_equal "555-0200", row[:phone]
    assert_equal "p2", row[:property_id]
    assert_equal "l2", row[:lease_id]
    assert_equal '["u1","u2"]', row[:unit_ids]
    assert_equal "CURRENT", row[:status]
    assert_equal "2025-06-01", row[:move_in_at]
    assert_equal "425", row[:balance_due]
  end

  def test_for_property
    DoorloopMcp::Models::Tenant.upsert_all([
      { "id" => "t1", "name" => "Alice A", "tenant" => { "firstName" => "Alice" }, "property" => "p1", "status" => "CURRENT" },
      { "id" => "t2", "name" => "Bob B", "tenant" => { "firstName" => "Bob" }, "property" => "p1", "status" => "CURRENT" },
      { "id" => "t3", "name" => "Charlie C", "tenant" => { "firstName" => "Charlie" }, "property" => "p2", "status" => "CURRENT" }
    ])

    tenants = DoorloopMcp::Models::Tenant.for_property("p1")
    assert_equal 2, tenants.length
  end

  def test_for_lease
    DoorloopMcp::Models::Tenant.upsert_all([
      { "id" => "t1", "name" => "Alice A", "tenant" => { "firstName" => "Alice" }, "property" => "p1", "lease" => "l1" },
      { "id" => "t2", "name" => "Bob B", "tenant" => { "firstName" => "Bob" }, "property" => "p1", "lease" => "l1" },
      { "id" => "t3", "name" => "Charlie C", "tenant" => { "firstName" => "Charlie" }, "property" => "p1", "lease" => "l2" }
    ])

    tenants = DoorloopMcp::Models::Tenant.for_lease("l1")
    assert_equal 2, tenants.length
  end

  def test_active
    DoorloopMcp::Models::Tenant.upsert_all([
      { "id" => "t1", "name" => "Current Tenant", "tenant" => { "firstName" => "Current" }, "property" => "p1", "status" => "CURRENT" },
      { "id" => "t2", "name" => "Past Tenant", "tenant" => { "firstName" => "Past" }, "property" => "p1", "status" => "PAST" }
    ])

    active = DoorloopMcp::Models::Tenant.active
    assert_equal 1, active.length
    assert_equal "Current Tenant", active.first.name
  end

  def test_upsert_updates_existing
    DoorloopMcp::Models::Tenant.upsert_all([{ "id" => "t1", "name" => "Old Name", "tenant" => { "firstName" => "Old" }, "property" => "p1" }])
    DoorloopMcp::Models::Tenant.upsert_all([{ "id" => "t1", "name" => "New Name", "tenant" => { "firstName" => "New" }, "property" => "p1" }])

    assert_equal 1, DoorloopMcp::Models::Tenant.count
    assert_equal "New Name", DoorloopMcp::Models::Tenant["t1"].name
  end

  def test_preserves_full_json
    DoorloopMcp::Models::Tenant.upsert_all([{
      "id" => "t1", "name" => "Test User",
      "tenant" => {
        "firstName" => "Test", "lastName" => "User",
        "portalInfo" => { "status" => "ACTIVE", "loginEmail" => "test@example.com" }
      },
      "property" => "p1"
    }])

    tenant = DoorloopMcp::Models::Tenant["t1"]
    api = tenant.to_api
    assert_equal "ACTIVE", api[:tenant][:portalInfo][:status]
  end

  def test_find_by_name
    DoorloopMcp::Models::Tenant.upsert_all([
      { "id" => "t1", "name" => "John Doe", "tenant" => { "firstName" => "John" }, "property" => "p1" },
      { "id" => "t2", "name" => "Jane Smith", "tenant" => { "firstName" => "Jane" }, "property" => "p1" }
    ])

    results = DoorloopMcp::Models::Tenant.find_by_name("John")
    assert_equal 1, results.length
    assert_equal "t1", results.first.id
  end

  def test_skips_without_id
    DoorloopMcp::Models::Tenant.upsert_all([
      { "id" => "t1", "name" => "Has ID", "tenant" => { "firstName" => "Has" } },
      { "name" => "No ID", "tenant" => { "firstName" => "No" } }
    ])
    assert_equal 1, DoorloopMcp::Models::Tenant.count
  end

  def test_clear
    DoorloopMcp::Models::Tenant.upsert_all([{ "id" => "t1", "name" => "Test", "tenant" => { "firstName" => "Test" } }])
    DoorloopMcp::Models::Tenant.clear!
    assert_equal 0, DoorloopMcp::Models::Tenant.count
  end
end
