# frozen_string_literal: true

module DoorLoopApp
  module Models
    class LeaseTransaction < Sequel::Model
      include JsonBacked

      TABLE = :lease_transactions

      # Actual API response fields (from /api/reports/lease-accounts-receivable/):
      #   id, type, date, totalAmount, runningBalance, reference, createdAt,
      #   lines: [{account, amount, memo}]
      #   "lease" is injected by LeaseTransactionsPage (not present in raw response)
      COLUMNS = {
        lease_id:        "lease",
        txn_type:        "type",
        amount:          "totalAmount",
        date:            "date",
        reference:       "reference",
        description:     "lines.0.memo",
        running_balance: "runningBalance"
      }.freeze

      def self.migrate!(db)
        if db.table_exists?(TABLE)
          cols = db[TABLE].columns
          # Drop and recreate if core columns are missing or schema is pre-v2
          # (v2 adds reference/running_balance, removes old description/status/property_id)
          unless cols.include?(:data) && cols.include?(:lease_id) && cols.include?(:reference)
            db.drop_table(TABLE)
          end
        end

        db.create_table?(TABLE) do
          String   :id,              primary_key: true
          String   :data,            null: false
          String   :lease_id
          String   :txn_type
          String   :amount
          String   :date
          String   :reference
          String   :description
          String   :running_balance
          DateTime :created_at
          DateTime :updated_at

          index :lease_id
          index :date
          index :txn_type
        end
      end

      def self.for_lease(lease_id)
        where(lease_id: lease_id.to_s).order(Sequel.desc(:date)).all
      end

      def self.recent_for_lease(lease_id, limit: 20)
        where(lease_id: lease_id.to_s).order(Sequel.desc(:date)).limit(limit).all
      end
    end
  end
end
