# frozen_string_literal: true

require "playwright"

module DoorloopMcp
  module Browser
    class Session
      attr_reader :page, :browser

      def initialize
        @execution = nil
        @browser = nil
        @page = nil
        @authenticated = false
        @mutex = Mutex.new
      end

      def start
        @mutex.synchronize do
          return if @page

          config = DoorloopMcp.configuration
          $stderr.puts "Launching browser (headless=#{config.headless})..."

          FileUtils.mkdir_p(config.profile_dir)

          @execution = Playwright.create(playwright_cli_executable_path: find_playwright_cli)

          extra_args = ENV.fetch("PLAYWRIGHT_CHROMIUM_ARGS", "").split
          @browser = @execution.playwright.chromium.launch_persistent_context(
            config.profile_dir,
            headless: config.headless,
            args: ["--disable-blink-features=AutomationControlled"] + extra_args,
            viewport: { width: 1280, height: 800 }
          )

          @page = @browser.pages.first || @browser.new_page
          $stderr.puts "Browser ready."
        end
      end

      def stop
        @mutex.synchronize do
          @browser&.close
          @execution&.stop
          @browser = nil
          @execution = nil
          @page = nil
          @authenticated = false
        end
      rescue => e
        $stderr.puts "Warning: Could not stop browser: #{e.message}"
      end

      def authenticated?
        @authenticated
      end

      def authenticate!
        start unless @page
        config = DoorloopMcp.configuration
        config.validate!

        login_page = Pages::LoginPage.new(self)
        result = login_page.login(config.email, config.password)

        @authenticated = true if result[:status] == :logged_in
        result
      end

      def submit_2fa_code(code)
        raise "No pending login — call authenticate! first" unless @page

        login_page = Pages::LoginPage.new(self)
        result = login_page.submit_2fa_code(code)
        @authenticated = true if result[:status] == :logged_in
        result
      end

      def ensure_authenticated!
        return if authenticated?

        if has_valid_session?
          @authenticated = true
          return
        end

        authenticate!
      end

      def navigate(path)
        config = DoorloopMcp.configuration
        url = path.start_with?("http") ? path : "#{config.url}#{path}"
        @page.goto(url, waitUntil: "domcontentloaded")
      end

      def current_url
        @page.url
      end

      def evaluate(expression)
        @page.evaluate(expression)
      end

      def text_content
        @page.evaluate("document.body.innerText")
      end

      # Extract auth tokens from cookies (for API layer)
      def extract_auth_tokens
        cookies = @browser.cookies
        auth_cookie = cookies.find do |c|
          c["name"].to_s.match?(/token|auth|session|jwt/i) && c["value"].to_s.length > 20
        end
        return nil unless auth_cookie

        { token: auth_cookie["value"], source: :cookie, name: auth_cookie["name"] }
      end

      private

      def has_valid_session?
        start unless @page
        $stderr.puts "Checking for valid session..."

        config = DoorloopMcp.configuration
        @page.goto(config.url, waitUntil: "domcontentloaded")
        sleep 2

        url = @page.url
        $stderr.puts "Session check — URL: #{url}"

        return false if url.include?("/login") || url.include?("/signin") || url.include?("/auth")

        $stderr.puts "Valid session found — skipping login."
        true
      rescue => e
        $stderr.puts "Session check failed: #{e.message}"
        false
      end

      def find_playwright_cli
        # Check common locations
        paths = [
          File.join(DoorloopMcp.root, "node_modules", ".bin", "playwright"),
          `which playwright 2>/dev/null`.strip
        ]
        paths.find { |p| !p.empty? && File.exist?(p) } || "npx playwright"
      end
    end
  end
end
