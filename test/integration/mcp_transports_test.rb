# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"
require "net/http"
require "socket"
require "timeout"

class MCPTransportsTest < Minitest::Test
  MODERN_VERSION = "2026-07-28"
  LEGACY_VERSION = "2025-11-25"
  SERVER_SCRIPT = <<~'RUBY'
    require "doorloop_app"
    DoorLoopApp.configure do |config|
      config.db_path = ":memory:"
      config.allow_paid_ai = false
      config.email = config.password = nil
    end
    DoorLoopApp::Server.run(http: ARGV[0] == "http", port: ARGV[1].to_i)
  RUBY

  def test_modern_http_discovery_and_tool_calls
    with_server("http") do |_, _, port|
      discover = http_rpc(port, rpc(1, "server/discover", modern_meta), MODERN_VERSION)
      assert_equal "complete", discover.dig("result", "resultType")
      check_tools_and_call(->(request) { http_rpc(port, request, MODERN_VERSION) }, modern_meta)
    end
  end

  def test_legacy_http_initialization_and_tool_calls
    with_server("http") do |_, _, port|
      initialized = http_rpc(port, initialization, LEGACY_VERSION)
      assert_equal LEGACY_VERSION, initialized.dig("result", "protocolVersion")
      check_tools_and_call(->(request) { http_rpc(port, request, LEGACY_VERSION) }, {})
      response = http_post(port, rpc(9, "tools/list"), LEGACY_VERSION, origin: "https://unrelated.example")
      assert_equal "403", response.code
    end
  end

  def test_modern_stdio_discovery_and_tool_calls
    with_server("stdio") do |input, output, _|
      send_line(input, rpc(1, "server/discover", modern_meta))
      assert_equal "complete", read_line(output).dig("result", "resultType")
      check_tools_and_call(->(request) { send_line(input, request); read_line(output) }, modern_meta)
      send_line(input, rpc(8, "tools/list", { _meta: modern_meta[:_meta].merge("io.modelcontextprotocol/protocolVersion" => "1900-01-01") }))
      assert_equal(-32022, read_line(output).dig("error", "code"))
    end
  end

  def test_legacy_stdio_initialization_and_tool_calls
    with_server("stdio") do |input, output, _|
      send_line(input, initialization)
      assert_equal LEGACY_VERSION, read_line(output).dig("result", "protocolVersion")
      send_line(input, { jsonrpc: "2.0", method: "notifications/initialized" })
      check_tools_and_call(->(request) { send_line(input, request); read_line(output) }, {})
    end
  end

  private

  def check_tools_and_call(exchange, meta)
    listed = exchange.call(rpc(2, "tools/list", meta))
    tools = listed.dig("result", "tools")
    assert_equal 9, tools&.size, listed.inspect
    properties = tools.find { |tool| tool["name"] == "doorloop_list_properties" }
    assert_equal true, properties.dig("annotations", "readOnlyHint")
    payment = tools.find { |tool| tool["name"] == "doorloop_receive_payment" }
    assert_equal false, payment.dig("annotations", "readOnlyHint")
    called = exchange.call(rpc(3, "tools/call", meta.merge(name: "doorloop_list_properties", arguments: {})))
    assert_equal false, called.dig("result", "isError"), called.inspect
    assert_kind_of Hash, called.dig("result", "structuredContent")
    invalid = exchange.call(rpc(4, "tools/call", meta.merge(name: "doorloop_list_properties", arguments: { unexpected: true })))
    assert invalid["error"] || invalid.dig("result", "isError"), invalid.inspect
  end

  def initialization
    rpc(1, "initialize", { protocolVersion: LEGACY_VERSION, capabilities: {}, clientInfo: { name: "doorloop-test", version: "1" } })
  end

  def modern_meta
    { _meta: { "io.modelcontextprotocol/protocolVersion" => MODERN_VERSION, "io.modelcontextprotocol/clientCapabilities" => {} } }
  end

  def rpc(id, method, params = {})
    { jsonrpc: "2.0", id: id, method: method, params: params }
  end

  def send_line(input, value)
    input.puts(JSON.generate(value))
    input.flush
  end

  def read_line(output)
    raise "MCP stdio response timed out" unless IO.select([output], nil, nil, 5)

    JSON.parse(output.gets || raise("MCP process closed stdout"))
  end

  def http_rpc(port, request, version)
    response = http_post(port, request, version)
    assert_equal "200", response.code, response.body
    assert_includes response["Content-Type"], "application/json"
    JSON.parse(response.body)
  end

  def http_post(port, request, version, origin: nil)
    http = Net::HTTP.new("127.0.0.1", port, nil)
    http.read_timeout = http.open_timeout = 5
    headers = { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream", "MCP-Protocol-Version" => version }
    headers["Origin"] = origin if origin
    if version == MODERN_VERSION
      headers["Mcp-Method"] = request[:method]
      headers["Mcp-Name"] = request.dig(:params, :name) if request.dig(:params, :name)
    end
    http.post("/mcp", JSON.generate(request), headers)
  end

  def with_server(mode)
    socket = TCPServer.new("127.0.0.1", 0)
    port = socket.addr[1]
    socket.close
    Open3.popen3(RbConfig.ruby, "-Ilib", "-e", SERVER_SCRIPT, mode, port.to_s) do |input, output, error, process|
      errors = Thread.new { error.read }
      if mode == "http"
        Timeout.timeout(5) do
          loop do
            begin
              TCPSocket.new("127.0.0.1", port).close
              break
            rescue Errno::ECONNREFUSED
              raise "MCP HTTP server exited: #{errors.value}" unless process.alive?
              sleep 0.03
            end
          end
        end
      end
      yield input, output, port
    ensure
      input.close unless input.closed?
      Process.kill("TERM", process.pid) if mode == "http" && process.alive?
      unless process.join(3)
        Process.kill("KILL", process.pid)
        process.join
      end
      errors.join
    end
  end
end
