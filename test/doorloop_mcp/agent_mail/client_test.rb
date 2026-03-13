# frozen_string_literal: true

require "test_helper"
require "agentmail"

class AgentMailClientTest < Minitest::Test
  include TestHelpers

  # Wraps a hash to mimic Agentmail::Response
  MockResponse = Struct.new(:body)

  def mock_response(hash)
    MockResponse.new(hash)
  end

  def setup
    DoorloopMcp.configuration.agentmail_api_key = "test-api-key"
    DoorloopMcp.configuration.agentmail_inbox_id = "inbox_123"
  end

  def teardown
    DoorloopMcp.configuration.agentmail_api_key = nil
    DoorloopMcp.configuration.agentmail_inbox_id = nil
  end

  def test_raises_without_api_key
    DoorloopMcp.configuration.agentmail_api_key = nil

    error = assert_raises(RuntimeError) do
      DoorloopMcp::AgentMail::Client.new
    end
    assert_equal "AGENTMAIL_API_KEY is required", error.message
  end

  def test_raises_without_inbox_id
    DoorloopMcp.configuration.agentmail_inbox_id = nil

    error = assert_raises(RuntimeError) do
      DoorloopMcp::AgentMail::Client.new
    end
    assert_equal "AGENTMAIL_INBOX_ID is required", error.message
  end

  def test_list_messages
    mock_agentmail = mock("agentmail_client")
    ::Agentmail::Client.expects(:new).with(api_key: "test-api-key").returns(mock_agentmail)

    mock_agentmail.expects(:request).with(
      :get,
      "/v0/inboxes/inbox_123/messages",
      params: { limit: 10 }
    ).returns(mock_response({ "messages" => [], "count" => 0 }))

    client = DoorloopMcp::AgentMail::Client.new
    result = client.list_messages

    assert_equal 0, result["count"]
    assert_empty result["messages"]
  end

  def test_list_messages_with_filters
    mock_agentmail = mock("agentmail_client")
    ::Agentmail::Client.expects(:new).with(api_key: "test-api-key").returns(mock_agentmail)

    mock_agentmail.expects(:request).with(
      :get,
      "/v0/inboxes/inbox_123/messages",
      params: { limit: 5, after: "2026-01-01T00:00:00Z", ascending: true }
    ).returns(mock_response({ "messages" => [], "count" => 0 }))

    client = DoorloopMcp::AgentMail::Client.new
    client.list_messages(limit: 5, after: "2026-01-01T00:00:00Z", ascending: true)
  end

  def test_get_message
    mock_agentmail = mock("agentmail_client")
    ::Agentmail::Client.expects(:new).with(api_key: "test-api-key").returns(mock_agentmail)

    mock_agentmail.expects(:request).with(
      :get,
      "/v0/inboxes/inbox_123/messages/msg_456"
    ).returns(mock_response({
      "message_id" => "msg_456",
      "subject" => "Your verification code",
      "text" => "Your code is 123456"
    }))

    client = DoorloopMcp::AgentMail::Client.new
    result = client.get_message("msg_456")

    assert_equal "msg_456", result["message_id"]
    assert_equal "Your verification code", result["subject"]
  end

  def test_wait_for_message_finds_match
    mock_agentmail = mock("agentmail_client")
    ::Agentmail::Client.expects(:new).with(api_key: "test-api-key").returns(mock_agentmail)

    # First poll returns matching message in list
    mock_agentmail.expects(:request).with(
      :get,
      "/v0/inboxes/inbox_123/messages",
      params: has_entries(ascending: true, limit: 25)
    ).returns(mock_response({
      "messages" => [
        {
          "message_id" => "msg_789",
          "from" => "noreply@doorloop.com",
          "subject" => "DoorLoop Verification Code"
        }
      ]
    }))

    # Then fetches full message
    mock_agentmail.expects(:request).with(
      :get,
      "/v0/inboxes/inbox_123/messages/msg_789"
    ).returns(mock_response({
      "message_id" => "msg_789",
      "from" => "noreply@doorloop.com",
      "subject" => "DoorLoop Verification Code",
      "text" => "Your code is 654321"
    }))

    client = DoorloopMcp::AgentMail::Client.new
    result = client.wait_for_message(
      from: "doorloop",
      subject_contains: "verification",
      timeout: 5
    )

    assert_equal "msg_789", result["message_id"]
    assert_equal "Your code is 654321", result["text"]
  end

  def test_wait_for_message_filters_non_matching
    mock_agentmail = mock("agentmail_client")
    ::Agentmail::Client.expects(:new).with(api_key: "test-api-key").returns(mock_agentmail)

    # Inbox has a spam message and a matching DoorLoop message
    mock_agentmail.stubs(:request).with(
      :get,
      "/v0/inboxes/inbox_123/messages",
      params: has_entries(ascending: true, limit: 25)
    ).returns(mock_response({
      "messages" => [
        { "message_id" => "msg_001", "from" => "spam@other.com", "subject" => "Buy stuff" },
        { "message_id" => "msg_002", "from" => "noreply@doorloop.com", "subject" => "Verification Code" }
      ]
    }))

    # Should skip msg_001 (wrong sender) and fetch msg_002
    mock_agentmail.expects(:request).with(
      :get,
      "/v0/inboxes/inbox_123/messages/msg_002"
    ).returns(mock_response({
      "message_id" => "msg_002",
      "from" => "noreply@doorloop.com",
      "subject" => "Verification Code",
      "text" => "Code: 111222"
    }))

    client = DoorloopMcp::AgentMail::Client.new
    result = client.wait_for_message(from: "doorloop", timeout: 10)

    assert_equal "msg_002", result["message_id"]
    assert_equal "Code: 111222", result["text"]
  end

  def test_wait_for_message_times_out
    mock_agentmail = mock("agentmail_client")
    ::Agentmail::Client.expects(:new).with(api_key: "test-api-key").returns(mock_agentmail)

    mock_agentmail.stubs(:request).with(
      :get,
      "/v0/inboxes/inbox_123/messages",
      params: has_entries(ascending: true, limit: 25)
    ).returns(mock_response({ "messages" => [] }))

    client = DoorloopMcp::AgentMail::Client.new
    client.stubs(:sleep)

    # Use a very short timeout that's already passed
    error = assert_raises(RuntimeError) do
      client.wait_for_message(from: "doorloop", timeout: 0)
    end
    assert_match(/Timed out waiting for email/, error.message)
  end

  def test_inbox
    mock_agentmail = mock("agentmail_client")
    ::Agentmail::Client.expects(:new).with(api_key: "test-api-key").returns(mock_agentmail)

    mock_inboxes = mock("inboxes")
    mock_agentmail.expects(:inboxes).returns(mock_inboxes)
    mock_inboxes.expects(:retrieve).with("inbox_123").returns({
      "inbox_id" => "inbox_123",
      "display_name" => "DoorLoop 2FA"
    })

    client = DoorloopMcp::AgentMail::Client.new
    result = client.inbox

    assert_equal "inbox_123", result["inbox_id"]
  end

  # --- extract_verification_code tests ---

  def test_extract_code_from_text_body
    message = { "text" => "Your 2-step verification code is: 031524\n\nDoorLoop will never ask you for this code." }
    assert_equal "031524", DoorloopMcp::AgentMail::Client.extract_verification_code(message)
  end

  def test_extract_code_from_html_body
    message = { "html" => '<meta>Your 2-step verification code is: 987654<br><br>DoorLoop will never ask you for this code.' }
    assert_equal "987654", DoorloopMcp::AgentMail::Client.extract_verification_code(message)
  end

  def test_extract_code_from_extracted_text
    message = { "extracted_text" => "verification code is: 112233" }
    assert_equal "112233", DoorloopMcp::AgentMail::Client.extract_verification_code(message)
  end

  def test_extract_code_prefers_text_over_html
    message = {
      "text" => "verification code is: 111111",
      "html" => "verification code is: 222222"
    }
    assert_equal "111111", DoorloopMcp::AgentMail::Client.extract_verification_code(message)
  end

  def test_extract_code_returns_nil_when_no_match
    message = { "text" => "Hello, this is a regular email." }
    assert_nil DoorloopMcp::AgentMail::Client.extract_verification_code(message)
  end

  def test_extract_code_returns_nil_for_empty_message
    assert_nil DoorloopMcp::AgentMail::Client.extract_verification_code({})
  end

  # --- wait_for_verification_code test ---

  def test_wait_for_verification_code
    mock_agentmail = mock("agentmail_client")
    ::Agentmail::Client.expects(:new).with(api_key: "test-api-key").returns(mock_agentmail)

    mock_agentmail.stubs(:request).with(
      :get,
      "/v0/inboxes/inbox_123/messages",
      params: has_entries(ascending: true, limit: 25)
    ).returns(mock_response({
      "messages" => [
        {
          "message_id" => "msg_2fa",
          "from" => "DoorLoop Security <support@doorloop.com>",
          "subject" => "DoorLoop 2-Step Verification Code"
        }
      ]
    }))

    mock_agentmail.expects(:request).with(
      :get,
      "/v0/inboxes/inbox_123/messages/msg_2fa"
    ).returns(mock_response({
      "message_id" => "msg_2fa",
      "from" => "DoorLoop Security <support@doorloop.com>",
      "subject" => "DoorLoop 2-Step Verification Code",
      "text" => "Your 2-step verification code is: 031524\n\nDoorLoop will never ask you for this code."
    }))

    client = DoorloopMcp::AgentMail::Client.new
    code = client.wait_for_verification_code(timeout: 5)

    assert_equal "031524", code
  end

  def test_wait_for_verification_code_raises_when_no_code_in_email
    mock_agentmail = mock("agentmail_client")
    ::Agentmail::Client.expects(:new).with(api_key: "test-api-key").returns(mock_agentmail)

    mock_agentmail.stubs(:request).with(
      :get,
      "/v0/inboxes/inbox_123/messages",
      params: has_entries(ascending: true, limit: 25)
    ).returns(mock_response({
      "messages" => [
        {
          "message_id" => "msg_bad",
          "from" => "support@doorloop.com",
          "subject" => "DoorLoop Verification Code"
        }
      ]
    }))

    mock_agentmail.expects(:request).with(
      :get,
      "/v0/inboxes/inbox_123/messages/msg_bad"
    ).returns(mock_response({
      "message_id" => "msg_bad",
      "subject" => "DoorLoop Verification Code",
      "text" => "This email has no code in it."
    }))

    client = DoorloopMcp::AgentMail::Client.new

    error = assert_raises(RuntimeError) do
      client.wait_for_verification_code(timeout: 5)
    end
    assert_match(/Could not extract verification code/, error.message)
  end
end
