# frozen_string_literal: true

require "test_helper"

class LoginToolTest < Minitest::Test
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

  def test_successful_login
    session = build_mock_session
    session.expects(:authenticate!).returns({ status: :logged_in })

    server = build_test_server(session: session)
    DoorLoopApp::Tools::LoginTool.register(server)
    result = call_tool(server, "doorloop_login")

    refute result[:isError]
    assert_match(/Successfully logged in/, result[:content].first[:text])
  end

  def test_two_factor_required
    session = build_mock_session
    session.expects(:authenticate!).returns({ status: :two_factor_required })

    server = build_test_server(session: session)
    DoorLoopApp::Tools::LoginTool.register(server)
    result = call_tool(server, "doorloop_login")

    refute result[:isError]
    assert_match(/Two-factor authentication required/, result[:content].first[:text])
    assert_match(/doorloop_submit_2fa/, result[:content].first[:text])
  end

  def test_login_failure
    session = build_mock_session
    session.expects(:authenticate!).raises(RuntimeError.new("Invalid credentials"))

    server = build_test_server(session: session)
    DoorLoopApp::Tools::LoginTool.register(server)
    result = call_tool(server, "doorloop_login")

    assert result[:isError]
    assert_match(/Login failed/, result[:content].first[:text])
    assert_match(/Invalid credentials/, result[:content].first[:text])
  end
end
