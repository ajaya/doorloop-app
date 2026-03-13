# frozen_string_literal: true

module DoorLoopApp
  module Models
    class Tenant < Sequel::Model
      include JsonBacked

      TABLE = :tenants

      COLUMNS = {
        name:         "name",
        first_name:   "tenant.firstName",
        last_name:    "tenant.lastName",
        email:        "tenant.emails.0.address",
        phone:        "tenant.phones.0.number",
        property_id:  "property",
        lease_id:     "lease",
        unit_ids:     "units",
        status:       "status",
        move_in_at:   "moveInAt",
        balance_due:  "balanceDue"
      }.freeze

      def self.migrate!(db)
        if db.table_exists?(TABLE)
          cols = db[TABLE].columns
          unless cols.include?(:data) && cols.include?(:lease_id)
            db.drop_table(TABLE)
          end
        end

        db.create_table?(TABLE) do
          String :id, primary_key: true
          String :data, null: false
          String :name
          String :first_name
          String :last_name
          String :email
          String :phone
          String :property_id
          String :lease_id
          String :unit_ids
          String :status
          String :move_in_at
          String :balance_due
          DateTime :created_at
          DateTime :updated_at

          index :property_id
          index :lease_id
          index :name
          index :email
          index :status
        end
      end

      def self.for_property(property_id)
        where(property_id: property_id.to_s).order(:name).all
      end

      def self.for_lease(lease_id)
        where(lease_id: lease_id.to_s).order(:name).all
      end

      def self.active
        where(status: "CURRENT").order(:name).all
      end
    end
  end
end
