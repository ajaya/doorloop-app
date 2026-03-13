# frozen_string_literal: true

require "test_helper"

class Submit2faToolTest < Minitest::Test
  include TestHelpers

  def test_successful_2fa_submission
    session = build_mock_session
    session.expects(:submit_2fa_code).with("123456").returns({ status: :logged_in })
    session.expects(:extract_auth_tokens).returns({ token: "jwt_token", token_type: :bearer })

    token_store = mock("token_store")
    token_store.expects(:update).with(token: "jwt_token", token_type: :bearer)

    server = build_test_server(session: session, token_store: token_store)
    DoorLoopApp::Tools::Submit2faTool.register(server)
    result = call_tool(server, "doorloop_submit_2fa", { "code" => "123456" })

    refute result[:isError]
    assert_match(/Successfully logged in/, result[:content].first[:text])
  end

  def test_2fa_submission_without_token_store
    session = build_mock_session
    session.expects(:submit_2fa_code).with("123456").returns({ status: :logged_in })

    server = build_test_server(session: session)
    DoorLoopApp::Tools::Submit2faTool.register(server)
    result = call_tool(server, "doorloop_submit_2fa", { "code" => "123456" })

    refute result[:isError]
    assert_match(/Successfully logged in/, result[:content].first[:text])
  end

  def test_2fa_submission_failure
    session = build_mock_session
    session.expects(:submit_2fa_code).with("000000").raises(RuntimeError.new("Login failed: still on login page after 60s"))

    server = build_test_server(session: session)
    DoorLoopApp::Tools::Submit2faTool.register(server)
    result = call_tool(server, "doorloop_submit_2fa", { "code" => "000000" })

    assert result[:isError]
    assert_match(/2FA submission failed/, result[:content].first[:text])
  end

  def test_2fa_no_pending_login
    session = build_mock_session
    session.expects(:submit_2fa_code).with("123456").raises(RuntimeError.new("No pending login"))

    server = build_test_server(session: session)
    DoorLoopApp::Tools::Submit2faTool.register(server)
    result = call_tool(server, "doorloop_submit_2fa", { "code" => "123456" })

    assert result[:isError]
    assert_match(/No pending login/, result[:content].first[:text])
  end
end
