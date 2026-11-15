# frozen_string_literal: true

module DoorLoopApp
  module Browser
    class Locator
      def initialize(driver, page, selector, index: 0)
        @driver, @page, @selector, @index = driver, page, selector, index
      end

      def first
        self.class.new(@driver, @page, @selector)
      end

      def count
        @driver.command("get", "count", @selector).fetch("count")
      end

      def click(timeout: 30_000)
        @driver.command("find", "nth", @index.to_s, @selector, "click", timeout: timeout)
      end

      def fill(value)
        @page.fill(@selector, value)
      end

      def check(timeout: 30_000)
        @driver.command("check", @selector, timeout: timeout)
      end

      def input_value
        evaluate("el => el.value")
      end

      def press(key)
        click
        @page.press(key)
      end

      def evaluate(expression)
        @page.evaluate(<<~JS)
          (() => {
            const el = document.querySelectorAll(#{JSON.generate(@selector)})[#{@index}];
            if (!el) throw new Error('Element not found');
            return (#{expression})(el);
          })()
        JS
      end
    end
  end
end
