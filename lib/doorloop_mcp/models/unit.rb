# frozen_string_literal: true

module DoorloopMcp
  module Models
    class Unit < Sequel::Model
      include JsonBacked

      TABLE = :units
      ID_FIELD = "unitId"

      COLUMNS = {
        name:        "unitName",
        property_id: "property",
        status:      "leaseStatus",
        rent:        "marketRent"
      }.freeze

      def self.migrate!(db)
        if db.table_exists?(TABLE)
          cols = db[TABLE].columns
          unless cols.include?(:data) && cols.include?(:property_id)
            db.drop_table(TABLE)
          end
        end

        db.create_table?(TABLE) do
          String :id, primary_key: true
          String :data, null: false
          String :name
          String :property_id
          String :status
          String :rent
          DateTime :created_at
          DateTime :updated_at

          index :property_id
          index :name
        end
      end

      def self.for_property(property_id)
        where(property_id: property_id.to_s).order(:name).all
      end
    end
  end
end
