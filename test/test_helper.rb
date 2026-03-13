# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "mocha/minitest"
require "doorloop_mcp"

# Use in-memory DB for tests
ENV["DOORLOOP_DB_PATH"] ||= ":memory:"

module TestHelpers
  def build_mock_page
    page = mock("page")
    page.stubs(:goto)
    page.stubs(:fill)
    page.stubs(:click)
    page.stubs(:evaluate).returns(nil)
    page.stubs(:url).returns("https://bansals.app.doorloop.com")
    page.stubs(:locator).returns(mock_locator([]))
    page.stubs(:keyboard).returns(mock_keyboard)
    page
  end

  def mock_locator(items = [])
    locator = mock("locator")
    locator.stubs(:all).returns(items)
    locator.stubs(:first).returns(items.first)
    locator.stubs(:count).returns(items.length)
    locator.stubs(:locator).returns(locator)
    locator
  end

  def mock_keyboard
    keyboard = mock("keyboard")
    keyboard.stubs(:press)
    keyboard.stubs(:type)
    keyboard
  end

  def build_mock_browser
    browser = mock("browser")
    browser.stubs(:cookies).returns([])
    browser.stubs(:close)
    browser.stubs(:pages).returns([])
    browser.stubs(:new_page).returns(build_mock_page)
    browser
  end

  def build_mock_session(authenticated: false)
    session = mock("session")
    mock_page = build_mock_page

    session.stubs(:authenticated?).returns(authenticated)
    session.stubs(:start)
    session.stubs(:stop)
    session.stubs(:navigate)
    session.stubs(:current_url).returns("https://bansals.app.doorloop.com")
    session.stubs(:evaluate).returns(nil)
    session.stubs(:text_content).returns("")
    session.stubs(:page).returns(mock_page)
    session.stubs(:browser).returns(build_mock_browser)
    session.stubs(:ensure_authenticated!)
    session.stubs(:authenticate!)
    session.stubs(:extract_auth_tokens).returns(nil)
    session
  end

  def build_server_context(session: nil, executor: nil, service: nil)
    ctx = { session: session || build_mock_session }
    ctx[:executor] = executor if executor
    ctx[:service]  = service  if service
    ctx
  end

  def build_test_server(server_context = {})
    ::MCP::Server.new(name: "test", version: "0.0.1", server_context: server_context)
  end

  def call_tool(server, name, arguments = {})
    request = {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: { name: name, arguments: arguments }
    }
    response = server.handle(request)
    response[:result]
  end
end
