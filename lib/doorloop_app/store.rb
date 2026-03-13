# frozen_string_literal: true

module DoorLoopApp
  class Store
    attr_reader :db

    def initialize(db_path:)
      @db = Sequel.sqlite(db_path)
      Models::Property.setup!(@db)
      Models::Unit.setup!(@db)
      Models::Lease.setup!(@db)
      Models::Tenant.setup!(@db)
      Models::LeaseTransaction.setup!(@db)
    end

    # --- Properties (delegate to model) ---

    def upsert_properties(properties)
      Models::Property.upsert_all(properties)
    end

    def all_properties
      Models::Property.order(:name).map(&:to_api)
    end

    def find_property(id)
      Models::Property[id]&.to_api
    end

    def find_property_by_name(name)
      Models::Property.find_by_name(name).map(&:to_api)
    end

    def properties_count
      Models::Property.count
    end

    def properties_stale?(max_age: 300)
      Models::Property.stale?(max_age: max_age)
    end

    def clear_properties
      Models::Property.clear!
    end

    # --- Units (delegate to model) ---

    def upsert_units(units)
      Models::Unit.upsert_all(units)
    end

    def all_units
      Models::Unit.order(:name).map(&:to_api)
    end

    def find_unit(id)
      Models::Unit[id]&.to_api
    end

    def units_for_property(property_id)
      Models::Unit.for_property(property_id).map(&:to_api)
    end

    def units_count
      Models::Unit.count
    end

    def clear_units
      Models::Unit.clear!
    end

    # --- Leases (delegate to model) ---

    def upsert_leases(leases)
      Models::Lease.upsert_all(leases)
    end

    def all_leases
      Models::Lease.order(:name).map(&:to_api)
    end

    def find_lease(id)
      Models::Lease[id]&.to_api
    end

    def leases_for_property(property_id)
      Models::Lease.for_property(property_id).map(&:to_api)
    end

    def active_leases
      Models::Lease.active.map(&:to_api)
    end

    def leases_count
      Models::Lease.count
    end

    def clear_leases
      Models::Lease.clear!
    end

    # --- Tenants (delegate to model) ---

    def upsert_tenants(tenants)
      Models::Tenant.upsert_all(tenants)
    end

    def all_tenants
      Models::Tenant.order(:name).map(&:to_api)
    end

    def find_tenant(id)
      Models::Tenant[id]&.to_api
    end

    def find_tenant_by_name(name)
      Models::Tenant.find_by_name(name).map(&:to_api)
    end

    def tenants_for_property(property_id)
      Models::Tenant.for_property(property_id).map(&:to_api)
    end

    def tenants_for_lease(lease_id)
      Models::Tenant.for_lease(lease_id).map(&:to_api)
    end

    def active_tenants
      Models::Tenant.active.map(&:to_api)
    end

    def tenants_count
      Models::Tenant.count
    end

    def clear_tenants
      Models::Tenant.clear!
    end

    # --- Lease Transactions (delegate to model) ---

    def upsert_lease_transactions(transactions)
      Models::LeaseTransaction.upsert_all(transactions)
    end

    def lease_transactions_for_lease(lease_id)
      Models::LeaseTransaction.for_lease(lease_id).map(&:to_api)
    end

    def recent_lease_transactions(lease_id, limit: 20)
      Models::LeaseTransaction.recent_for_lease(lease_id, limit: limit).map(&:to_api)
    end

    def lease_transactions_count
      Models::LeaseTransaction.count
    end

    def clear_lease_transactions
      Models::LeaseTransaction.clear!
    end
  end
end
