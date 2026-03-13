# frozen_string_literal: true

require "test_helper"
require "anthropic"

class VisionClientTest < Minitest::Test
  def setup
    @original_env = ENV.to_hash
    ENV["ANTHROPIC_API_KEY"] = "test_key"
    DoorloopMcp.instance_variable_set(:@configuration, nil)
  end

  def teardown
    ENV.replace(@original_env)
    DoorloopMcp.instance_variable_set(:@configuration, nil)
  end

  def test_extract_from_text_returns_structured_data
    mock_anthropic = mock("anthropic_client")
    mock_messages = mock("messages")
    mock_anthropic.stubs(:messages).returns(mock_messages)

    content_block = mock("content_block")
    content_block.stubs(:text).returns('{"data": [{"name": "Oak Apartments", "id": "123"}]}')
    response = mock("response")
    response.stubs(:content).returns([content_block])

    mock_messages.expects(:create).returns(response)
    Anthropic::Client.expects(:new).with(api_key: "test_key").returns(mock_anthropic)

    client = DoorloopMcp::Vision::Client.new
    result = client.extract_from_text(
      page_text: "Properties: Oak Apartments 123 Main St",
      prompt: "Extract all properties."
    )

    assert_instance_of DoorloopMcp::Vision::VisionResult, result
    assert_equal 1, result.data.length
    assert_equal "Oak Apartments", result.data.first["name"]
  end

  def test_handles_json_in_code_fences
    mock_anthropic = mock("anthropic_client")
    mock_messages = mock("messages")
    mock_anthropic.stubs(:messages).returns(mock_messages)

    content_block = mock("content_block")
    content_block.stubs(:text).returns("```json\n{\"data\": [{\"name\": \"Test\"}]}\n```")
    response = mock("response")
    response.stubs(:content).returns([content_block])

    mock_messages.expects(:create).returns(response)
    Anthropic::Client.expects(:new).with(api_key: "test_key").returns(mock_anthropic)

    client = DoorloopMcp::Vision::Client.new
    result = client.extract_from_text(page_text: "test", prompt: "test")

    assert_equal [{ "name" => "Test" }], result.data
  end

  def test_handles_invalid_json_response
    mock_anthropic = mock("anthropic_client")
    mock_messages = mock("messages")
    mock_anthropic.stubs(:messages).returns(mock_messages)

    content_block = mock("content_block")
    content_block.stubs(:text).returns("not valid json at all")
    response = mock("response")
    response.stubs(:content).returns([content_block])

    mock_messages.expects(:create).returns(response)
    Anthropic::Client.expects(:new).with(api_key: "test_key").returns(mock_anthropic)

    client = DoorloopMcp::Vision::Client.new
    result = client.extract_from_text(page_text: "test", prompt: "test")

    assert_equal [], result.data
  end
end
