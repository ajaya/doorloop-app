# frozen_string_literal: true

module DoorLoopApp
  module Browser
    module WaitHelpers
      def wait_for_url(pattern, timeout: 30)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        loop do
          return if session.current_url.match?(pattern)
          if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
            raise "Timed out waiting for URL matching #{pattern} (current: #{session.current_url})"
          end
          sleep 1
        end
      end
    end
  end
end
