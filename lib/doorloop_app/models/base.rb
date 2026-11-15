# frozen_string_literal: true

module DoorLoopApp
  module Models
    # Sequel needs a database even to define a named model. Use an isolated,
    # in-memory database until Store binds each model to its actual table.
    Base = Sequel::Model(Sequel.sqlite)
    Base.require_valid_table = false
  end
end
