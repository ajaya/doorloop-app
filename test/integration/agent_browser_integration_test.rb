# frozen_string_literal: true

require "test_helper"
require "webrick"
require "tmpdir"
require "open3"
require "rbconfig"

class AgentBrowserIntegrationTest < Minitest::Test
  def test_authentication_survives_a_full_process_and_browser_restart
    skip "Set RUN_BROWSER_TESTS=1 to test local Chrome with agent-browser" unless ENV["RUN_BROWSER_TESTS"] == "1"

    Dir.mktmpdir("doorloop-browser-integration") do |dir|
      server = WEBrick::HTTPServer.new(Port: 0, BindAddress: "127.0.0.1", Logger: WEBrick::Log.new(File::NULL), AccessLog: [])
      mutations = []
      server.mount_proc("/") do |request, response|
        response["Content-Type"] = "text/html"
        if request.path == "/login"
          response["Set-Cookie"] = "trusted_device=remembered; HttpOnly; SameSite=Lax; Max-Age=86400; Path=/"
          cookie = WEBrick::Cookie.new("browser_session", "alive")
          cookie.path = "/"
          response.cookies << cookie
          response.body = '<title>Fixture login</title><script>localStorage.setItem("trusted", "yes"); sessionStorage.setItem("tab_session", "alive")</script>'
        elsif request.path.start_with?("/api/")
          response["Content-Type"] = "application/json"
          if request["Cookie"].to_s.include?("trusted_device=remembered") && request["Authorization"] == "Bearer fixture" && request["X-CSRF-Token"] == "fixture-csrf" && request["tokenId"] == "fixture-token-id"
            mutations << JSON.parse(request.body) if request.path == "/api/test-mutations" && request.request_method == "POST"
            if request.path == "/api/properties/custom-fields" && request.request_method == "POST"
              raise "search body was changed" unless JSON.parse(request.body) == { "filter_active" => "true", "page_number" => 1, "page_size" => 50 }
            end
            response.body = JSON.generate({ data: [{ id: "p1", name: "Fixture property", extra: { preserved: true } }], query: request.query_string })
          else
            response.status = 401
            response.body = '{"error":"authentication required"}'
          end
        elsif request["Cookie"].to_s.include?("trusted_device=remembered")
          response.body = <<~HTML
            <title>Dashboard</title><input id="memo"><input id="remember" type="checkbox"><button onclick="window.clicked=true">Sign in</button>
            <script>fetch('/api/properties/custom-fields', {method: 'POST', headers: {Authorization: 'Bearer fixture', 'X-CSRF-Token': 'fixture-csrf', tokenId: 'fixture-token-id', 'Content-Type': 'application/json'}, body: JSON.stringify({filter_active: 'true', page_number: 1, page_size: 50})})</script>
          HTML
        else
          response.status = 302
          response["Location"] = "/auth/login"
          response.body = '<input type="password">'
        end
      end
      thread = Thread.new { server.start }
      base = "http://127.0.0.1:#{server.config[:Port]}"
      script = <<~'RUBY'
        require "doorloop_app"
        config = DoorLoopApp.configuration
        config.url = ARGV[0]
        config.profile_dir = File.join(ARGV[1], "profile")
        config.api_registry_path = File.join(ARGV[1], "routes.json")
        config.browser_executable = ENV["DOORLOOP_BROWSER_EXECUTABLE"]
        config.headless = true
        session = DoorLoopApp::Browser::Session.new
        begin
          if ARGV[2] == "reuse"
            abort "discovered route was not persisted" unless session.registry.endpoint("list_properties")
          end
          session.start
          session.navigate("/login") if ARGV[2] == "login"
          session.ensure_authenticated!
          abort "trusted-device storage was lost" unless session.evaluate('localStorage.getItem("trusted")') == "yes"
          abort "session-only cookie was lost" unless session.browser.cookies.any? { |cookie| cookie["name"] == "browser_session" && cookie["value"] == "alive" }
          abort "tab session storage was lost" unless session.evaluate('sessionStorage.getItem("tab_session")') == "alive"
          captured = session.page.expect_response(->(r) { r.url.include?("/api/properties/") && r.status == 200 }) { session.navigate("/") }
          abort "network response missing" unless JSON.parse(captured.body)["data"].first["id"] == "p1"
          client = DoorLoopApp::Api::Client.new(session: session)
          properties = DoorLoopApp::Api::Endpoints::Properties.new(client).list_all
          abort "discovered API route lost fields" unless properties.first.dig("extra", "preserved")
          data = client.get("/api/properties/custom-fields", params: { search: "a&b ' quote" })
          abort "API response was altered" unless data["data"].first.dig("extra", "preserved")
          abort "query encoding failed" unless URI.decode_www_form(data["query"]).to_h["search"] == "a&b ' quote"
          session.page.locator("#memo").fill("value -- with quotes '")
          abort "input fill failed" unless session.page.locator("#memo").input_value == "value -- with quotes '"
          session.page.click_button("Sign in")
          abort "semantic button click failed" unless session.evaluate("window.clicked")
          session.page.locator("#remember").check
          session.page.locator("#remember").check
          abort "remember-device selection was toggled off" unless session.evaluate('document.querySelector("#remember").checked')
          client.post("/api/test-mutations", body: { amount: "12.34" })
          begin
            client.get("https://other.example/api/test")
            abort "cross-origin API was allowed"
          rescue ArgumentError
          end
          puts "browser API and trusted session verified"
        ensure
          session.stop
        end
      RUBY

      %w[login reuse].each do |mode|
        output, status = Open3.capture2e(RbConfig.ruby, "-Ilib", "-e", script, base, dir, mode)
        assert status.success?, "#{mode}: #{output}"
        assert_includes output, "browser API and trusted session verified"
      end
      assert_equal [{ "amount" => "12.34" }, { "amount" => "12.34" }], mutations
    ensure
      server&.shutdown
      thread&.join
    end
  end
end
