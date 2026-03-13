# frozen_string_literal: true

require "test_helper"

class SessionTest < Minitest::Test
  include TestHelpers

  def setup
    @original_env = ENV.to_hash
    ENV["DOORLOOP_EMAIL"] = "test@example.com"
    ENV["DOORLOOP_PASSWORD"] = "secret"
    DoorloopMcp.instance_variable_set(:@configuration, nil)
  end

  def teardown
    ENV.replace(@original_env)
    DoorloopMcp.instance_variable_set(:@configuration, nil)
  end

  def test_initialize_not_authenticated
    session = DoorloopMcp::Browser::Session.new
    refute session.authenticated?
  end

  def test_current_url_delegates_to_page
    session = DoorloopMcp::Browser::Session.new
    mock_page = mock("page")
    mock_page.expects(:url).returns("https://bansals.app.doorloop.com/properties")
    session.instance_variable_set(:@page, mock_page)

    assert_equal "https://bansals.app.doorloop.com/properties", session.current_url
  end

  def test_evaluate_delegates_to_page
    session = DoorloopMcp::Browser::Session.new
    mock_page = mock("page")
    mock_page.expects(:evaluate).with("document.title").returns("DoorLoop")
    session.instance_variable_set(:@page, mock_page)

    assert_equal "DoorLoop", session.evaluate("document.title")
  end

  def test_text_content_delegates_to_page
    session = DoorloopMcp::Browser::Session.new
    mock_page = mock("page")
    mock_page.expects(:evaluate).with("document.body.innerText").returns("Hello World")
    session.instance_variable_set(:@page, mock_page)

    assert_equal "Hello World", session.text_content
  end
end
