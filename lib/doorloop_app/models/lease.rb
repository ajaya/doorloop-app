# frozen_string_literal: true

module DoorLoopApp
  module Models
    class Lease < Sequel::Model
      include JsonBacked

      TABLE = :leases

      COLUMNS = {
        name:               "name",
        property_id:        "property",
        unit_ids:           "units",
        status:             "status",
        start_date:         "start",
        end_date:           "end",
        total_rent:         "totalRecurringRent",
        balance:            "totalBalanceDue",
        outstanding_balance: "outstandingBalance",
        overdue_balance:    "overdueBalance"
      }.freeze

      def self.migrate!(db)
        if db.table_exists?(TABLE)
          cols = db[TABLE].columns
          unless cols.include?(:data) && cols.include?(:unit_ids)
            db.drop_table(TABLE)
          end
        end

        db.create_table?(TABLE) do
          String :id, primary_key: true
          String :data, null: false
          String :name
          String :property_id
          String :unit_ids
          String :status
          String :start_date
          String :end_date
          String :total_rent
          String :balance
          String :outstanding_balance
          String :overdue_balance
          DateTime :created_at
          DateTime :updated_at

          index :property_id
          index :status
          index :name
        end
      end

      def self.for_property(property_id)
        where(property_id: property_id.to_s).order(:name).all
      end

      def self.active
        where(status: "ACTIVE").order(:name).all
      end
    end
  end
end
