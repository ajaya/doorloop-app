# frozen_string_literal: true

module DoorLoopApp
  module Api
    module Endpoints
      class Units < Base
        OPERATION = "list_units"

        def list_all(property_id: nil)
          params = property_id ? { "filter_properties" => property_id } : {}
          fetch(params: params, omit: %w[filter_properties property_id])
        end
      end
    end
  end
end
