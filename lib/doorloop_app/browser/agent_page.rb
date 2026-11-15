# frozen_string_literal: true

module DoorLoopApp
  module Browser
    # Page operations used by login, payment preparation and API discovery.
    # Data retrieval reads network responses, never text scraped from tables.
    class AgentPage
      def initialize(driver, on_response: nil)
        @driver = driver
        @on_response = on_response
      end

      def goto(url, waitUntil: "domcontentloaded")
        @driver.command("open", url)
      end

      def url
        @driver.command("get", "url").fetch("url")
      end

      def evaluate(script)
        @driver.command("eval", script)["result"]
      end

      def fill(selector, value)
        @driver.command("fill", selector, "--", value.to_s)
      end

      def click(selector)
        @driver.command("click", selector)
      end

      def click_button(name)
        @driver.command("find", "role", "button", "click", "--name", name, "--exact")
      end

      def keyboard
        self
      end

      def press(key)
        @driver.command("press", key)
      end

      def locator(selector)
        Locator.new(@driver, self, selector)
      end

      def wait_for_selector(selector, timeout: 10_000)
        @driver.command("wait", selector, timeout: timeout)
      end

      def expect_response(predicate, timeout: 15_000)
        @driver.command("network", "requests", "--clear")
        yield
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout / 1000.0
        loop do
          requests = @driver.command("network", "requests").fetch("requests", [])
          requests.reverse_each do |entry|
            candidate = response(entry)
            next unless predicate.call(candidate)

            detail = @driver.command("network", "request", entry.fetch("requestId"))
            next unless detail["responseBody"].is_a?(String)

            captured = response(detail)
            next if @on_response && @on_response.call(captured) == false
            return captured
          end
          raise Error, "Timed out waiting for an API response" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          sleep 0.2
        end
      end

      private

      def response(entry)
        Response.new(url: entry["url"].to_s, status: entry["status"].to_i,
                     body: entry["responseBody"], headers: entry["headers"] || {}, method: entry["method"] || "GET")
      end
    end
  end
end
