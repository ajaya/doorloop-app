# frozen_string_literal: true

module DoorLoopApp
  module Api
    module Endpoints
      class Tenants < Base
        OPERATION = "list_tenants"

        def list_all
          fetch
        end

        def search(query:)
          list_all&.select do |tenant|
            [tenant["name"], tenant["firstName"], tenant["lastName"]].compact.join(" ").downcase.include?(query.downcase)
          end
        end
      end
    end
  end
end
