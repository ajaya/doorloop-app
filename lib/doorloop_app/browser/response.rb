# frozen_string_literal: true

module DoorLoopApp
  module Browser
    Response = ::Data.define(:url, :status, :body, :headers, :method)
  end
end
