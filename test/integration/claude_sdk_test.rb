# frozen_string_literal: true

require "test_helper"
require "webrick"
require "anthropic"

class ClaudeSDKTest < Minitest::Test
  def test_current_official_sdk_serializes_requests_and_handles_thinking_blocks
    requests = []
    server = WEBrick::HTTPServer.new(Port: 0, BindAddress: "127.0.0.1", Logger: WEBrick::Log.new(File::NULL), AccessLog: [])
    server.mount_proc("/") do |request, response|
      body = JSON.parse(request.body)
      requests << { path: request.path, version: request["anthropic-version"], body: body }
      text = body["model"].include?("haiku") ? '{"id":"t1"}' : '{"data":[{"id":"p1"}]}'
      response["Content-Type"] = "application/json"
      response.body = JSON.generate({
        id: "msg_fixture", type: "message", role: "assistant", model: body["model"],
        content: [{ type: "thinking", thinking: "fixture", signature: "fixture" }, { type: "text", text: text }],
        stop_reason: "end_turn", stop_sequence: nil, usage: { input_tokens: 10, output_tokens: 10 }
      })
    end
    thread = Thread.new { server.start }
    client = Anthropic::Client.new(api_key: "fixture", base_url: "http://127.0.0.1:#{server.config[:Port]}")
    Anthropic::Client.stubs(:new).with(api_key: "fixture").returns(client)
    config = DoorLoopApp.configuration
    config.stubs(:anthropic_api_key).returns("fixture")
    config.stubs(:vision_configured?).returns(true)

    vision = DoorLoopApp::Vision::Client.new(model: "claude-sonnet-5-5")
    assert_equal [{ "id" => "p1" }], vision.extract_from_text(page_text: "fixture", prompt: "Extract").data
    tenant = { id: "t1", name: "Fixture tenant" }
    assert_equal tenant, DoorLoopApp::LLM::TenantMatcher.new(model: "claude-haiku-5-5").find("Fixture", [tenant])
    assert_equal 2, requests.size
    requests.each do |request|
      assert_equal "/v1/messages", request[:path]
      assert_equal "2026-10-21", request[:version]
      assert_equal({ "type" => "ephemeral" }, request[:body]["cache_control"])
    end
    assert_kind_of String, requests.first[:body]["system"]
  ensure
    server&.shutdown
    thread&.join
  end
end
