# frozen_string_literal: true

require "test_helper"

class SessionTest < Minitest::Test
  include TestHelpers

  def setup
    @original_env = ENV.to_hash
    ENV["DOORLOOP_EMAIL"] = "test@example.com"
    ENV["DOORLOOP_PASSWORD"] = "secret"
    DoorLoopApp.instance_variable_set(:@configuration, nil)
  end

  def teardown
    ENV.replace(@original_env)
    DoorLoopApp.instance_variable_set(:@configuration, nil)
  end

  def test_initialize_not_authenticated
    session = DoorLoopApp::Browser::Session.new
    refute session.authenticated?
  end

  def test_current_url_delegates_to_page
    session = DoorLoopApp::Browser::Session.new
    mock_page = mock("page")
    mock_page.expects(:url).returns("https://bansals.app.doorloop.com/properties")
    session.instance_variable_set(:@page, mock_page)

    assert_equal "https://bansals.app.doorloop.com/properties", session.current_url
  end

  def test_evaluate_delegates_to_page
    session = DoorLoopApp::Browser::Session.new
    mock_page = mock("page")
    mock_page.expects(:evaluate).with("document.title").returns("DoorLoop")
    session.instance_variable_set(:@page, mock_page)

    assert_equal "DoorLoop", session.evaluate("document.title")
  end

  def test_text_content_delegates_to_page
    session = DoorLoopApp::Browser::Session.new
    mock_page = mock("page")
    mock_page.expects(:evaluate).with("document.body.innerText").returns("Hello World")
    session.instance_variable_set(:@page, mock_page)

    assert_equal "Hello World", session.text_content
  end

  def test_start_uses_the_local_agent_browser_driver
    driver = mock("agent_browser")
    DoorLoopApp::Browser::AgentBrowser.expects(:new).returns(driver)
    driver.expects(:command).with("open", "about:blank").returns({})
    session = DoorLoopApp::Browser::Session.new
    session.start

    assert_instance_of DoorLoopApp::Browser::AgentPage, session.page
    assert_same driver, session.browser
  end

  def test_api_requests_reject_other_origins_before_opening_a_browser
    session = DoorLoopApp::Browser::Session.new
    session.expects(:start).never
    assert_raises(ArgumentError) { session.request(:get, "https://other.example/api/tenants") }
    assert_raises(ArgumentError) { session.request(:get, "/auth/login") }
  end

  def test_api_401_invalidates_the_session_without_retrying_a_write
    session = DoorLoopApp::Browser::Session.new
    session.stubs(:ensure_authenticated!)
    session.stubs(:capture_api_headers)
    session.instance_variable_set(:@authenticated, true)
    page = mock("page")
    page.expects(:evaluate).once.returns({ "status" => 401, "body" => "Unauthorized" })
    session.instance_variable_set(:@page, page)

    assert_raises(DoorLoopApp::Api::AuthenticationError) { session.request(:post, "/api/payments", body: { amount: 1 }) }
    refute session.authenticated?
  end

  def test_pending_2fa_is_reported_instead_of_running_a_request
    session = DoorLoopApp::Browser::Session.new
    session.stubs(:has_valid_session?).returns(false)
    session.stubs(:authenticate!).returns({ status: :two_factor_required })
    assert_raises(DoorLoopApp::Api::AuthenticationError) { session.ensure_authenticated! }
  end

  def test_an_expired_session_without_credentials_points_to_manual_login
    config = DoorLoopApp::Configuration.new
    config.email = config.password = nil
    session = DoorLoopApp::Browser::Session.new(config: config)
    session.stubs(:start)
    session.stubs(:has_valid_session?).returns(false)
    error = assert_raises(DoorLoopApp::Api::AuthenticationError) { session.authenticate! }
    assert_includes error.message, "login --manual"
  end

  def test_a_valid_saved_session_authenticates_without_saved_credentials
    config = DoorLoopApp::Configuration.new
    config.email = config.password = nil
    session = DoorLoopApp::Browser::Session.new(config: config)
    session.stubs(:start)
    session.stubs(:has_valid_session?).returns(true)
    assert_equal :logged_in, session.authenticate![:status]
    assert session.authenticated?
  end

  def test_browser_fetch_failure_invalidates_cached_authentication
    session = DoorLoopApp::Browser::Session.new
    session.stubs(:ensure_authenticated!)
    session.stubs(:capture_api_headers)
    session.instance_variable_set(:@authenticated, true)
    page = mock("page")
    page.expects(:evaluate).raises(DoorLoopApp::Browser::Error.new("fetch rejected a redirect"))
    session.instance_variable_set(:@page, page)
    assert_raises(DoorLoopApp::Api::Error) { session.request(:get, "/api/properties") }
    refute session.authenticated?
  end
end
