# frozen_string_literal: true

module DoorLoopApp
  module Api
    module Endpoints
      class Leases < Base
        OPERATION = "list_leases"

        def list_all(property_id: nil, status: nil)
          fetch(params: status ? { "filter_status" => status } : {})
        end
      end
    end
  end
end
