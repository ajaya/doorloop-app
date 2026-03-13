# frozen_string_literal: true

module DoorloopMcp
  module Browser
    class PageObject
      include WaitHelpers

      attr_reader :session

      def initialize(session = nil)
        @session = session || DoorloopMcp.session
      end

      private

      def page
        session.page
      end

      def navigate_to(path)
        session.navigate(path)
      end

      def log(msg)
        $stderr.puts "[#{self.class.name.split("::").last}] #{msg}"
      end
    end
  end
end
