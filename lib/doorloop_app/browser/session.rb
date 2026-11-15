# frozen_string_literal: true

require "json"
require "uri"

module DoorLoopApp
  module Browser
    class Session
      attr_reader :page, :browser

      def initialize(config: DoorLoopApp.configuration)
        @config = config
        @browser = nil
        @page = nil
        @authenticated = false
        @api_headers = {}
        @mutex = Mutex.new
      end

      def registry
        @registry ||= Api::Registry.new(path: @config.api_registry_path)
      end

      def start
        @mutex.synchronize do
          return if @page

          @browser = AgentBrowser.new(config: @config)
          @browser.command("open", "about:blank")
          @page = AgentPage.new(@browser, on_response: method(:observe_response))
        end
      end

      def stop
        @mutex.synchronize do
          @browser&.close
          @browser = nil
          @page = nil
          @authenticated = false
          @api_headers = {}
        end
      rescue => e
        $stderr.puts "Warning: Could not stop browser: #{e.message}"
      end

      def authenticated?
        @authenticated
      end

      def confirm_authenticated!
        raise Api::AuthenticationError, "Login is not complete; finish DoorLoop login and 2FA in the browser" unless has_valid_session?

        @authenticated = true
      end

      def authenticate!
        start unless @page
        if has_valid_session?
          @authenticated = true
          return { status: :logged_in }
        end

        if @config.email.to_s.empty? || @config.password.to_s.empty?
          raise Api::AuthenticationError, "No valid saved session. Run doorloop login --manual to complete login and 2FA in Chrome"
        end

        login_page = Pages::LoginPage.new(self)
        result = login_page.login(@config.email, @config.password)

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

        result = authenticate!
        unless result[:status] == :logged_in
          raise Api::AuthenticationError, "DoorLoop needs two-factor authentication; submit the code or run doorloop login --manual"
        end
      end

      def navigate(path)
        url = URI.join(@config.url, path).to_s
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

      # All DoorLoop HTTP runs inside Chrome, retaining HttpOnly cookies,
      # same-origin policy, browser identity and any observed auth/CSRF headers.
      # Writes are never automatically retried.
      def request(method, path, params: {}, body: nil)
        url = api_url(path)
        query = URI.decode_www_form(url.query || "") + params.to_a
        url.query = URI.encode_www_form(query) unless query.empty?
        ensure_authenticated!
        capture_api_headers
        payload = { url: url.to_s, method: method.to_s.upcase, headers: @api_headers, body: body }
        result = evaluate(<<~JS)
          (async () => {
            const request = #{JSON.generate(payload)};
            const url = new URL(request.url);
            if (url.origin !== location.origin || !url.pathname.startsWith('/api/')) {
              throw new Error('API request must stay on the DoorLoop origin');
            }
            const options = {
              method: request.method, credentials: 'include', redirect: 'error',
              headers: {...request.headers, Accept: 'application/json'},
              signal: AbortSignal.timeout(30000)
            };
            if (request.body !== null) {
              options.headers['Content-Type'] = 'application/json';
              options.body = JSON.stringify(request.body);
            }
            const response = await fetch(url, options);
            return {status: response.status, body: await response.text()};
          })()
        JS
        status = result.fetch("status")
        if [401, 403].include?(status)
          @authenticated = false
          @api_headers = {}
          raise Api::AuthenticationError, "DoorLoop denied the API request (#{status}); check login and permissions"
        end
        raise Api::Error, "DoorLoop API returned HTTP #{status}" unless (200...300).cover?(status)

        result["body"].to_s.empty? ? nil : JSON.parse(result.fetch("body"))
      rescue JSON::ParserError
        raise Api::Error, "DoorLoop API returned invalid JSON"
      rescue Browser::Error
        @authenticated = false
        @api_headers = {}
        raise Api::Error, "Browser API request failed; check local Chrome and the DoorLoop login"
      end

      private

      def has_valid_session?
        start unless @page
        $stderr.puts "Checking for valid session..."

        @page.goto(@config.url, waitUntil: "domcontentloaded")
        sleep 2

        url = @page.url
        return false unless same_origin?(URI.parse(url), URI.parse(@config.url))
        return false if URI.parse(url).path.match?(%r{/(?:login|signin|auth)(?:/|$)}i)
        return false if @page.evaluate("!!document.querySelector('input[type=password]')")
        return false if text_content.match?(/verify you are human|access denied|verification code|two.factor authentication/i)

        $stderr.puts "Valid session found — skipping login."
        true
      rescue => e
        $stderr.puts "Session check failed: #{e.message}"
        false
      end

      def api_url(path)
        url = URI.join(@config.url, path)
        unless same_origin?(url, URI.parse(@config.url)) && url.path.start_with?("/api/")
          raise ArgumentError, "API requests must use a /api/ path on the configured DoorLoop origin"
        end
        url
      end

      def same_origin?(left, right)
        [left.scheme, left.host, left.port] == [right.scheme, right.host, right.port]
      end

      def capture_api_headers
        @browser.command("network", "requests").fetch("requests", []).each do |entry|
          next unless entry["status"] == 200 && entry["method"] == "GET"

          observe_response(Response.new(url: entry["url"], status: entry["status"],
                                        body: nil, headers: entry["headers"] || {}, method: "GET"))
        end
      end

      def observe_response(response)
        api_url(response.url) # Never copy authentication headers across origins.
        response.headers.each do |name, value|
          @api_headers[name.downcase] = value if name.match?(/\A(?:authorization|x-.+)\z/i)
        end
        registry.record_response(response)
        true
      rescue ArgumentError, URI::InvalidURIError
        false
      end
    end
  end
end
