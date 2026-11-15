# frozen_string_literal: true

module DoorLoopApp
  module Api
    module Endpoints
      class LeaseTransactions < Base
        OPERATION = "list_lease_transactions"

        def list_all(lease_id:)
          fetch(params: { "filter_lease" => lease_id })&.map { |item| item.merge("lease" => lease_id) }
        end
      end
    end
  end
end
