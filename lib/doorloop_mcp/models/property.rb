# frozen_string_literal: true

module DoorloopMcp
  module Models
    class Property < Sequel::Model
      include JsonBacked

      TABLE = :properties

      COLUMNS = {
        name:          "name",
        address:       %w[address.street1 address.city address.state address.zip],
        property_type: "type",
        units_count:   "numActiveUnits"
      }.freeze

      def self.migrate!(db)
        if db.table_exists?(TABLE)
          cols = db[TABLE].columns
          unless cols.include?(:data) && cols.include?(:name)
            db.drop_table(TABLE)
          end
        end

        db.create_table?(TABLE) do
          String :id, primary_key: true
          String :data, null: false
          String :name
          String :address
          String :property_type
          String :units_count
          DateTime :created_at
          DateTime :updated_at

          index :name
        end
      end
    end
  end
end
