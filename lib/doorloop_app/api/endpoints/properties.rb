# frozen_string_literal: true

module DoorLoopApp
  module Api
    module Endpoints
      class Properties < Base
        OPERATION = "list_properties"

        def list_all
          fetch
        end
      end
    end
  end
end
