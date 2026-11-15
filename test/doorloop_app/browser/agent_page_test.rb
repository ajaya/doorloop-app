# frozen_string_literal: true

require "test_helper"

class AgentPageTest < Minitest::Test
  def test_response_capture_reads_the_network_body_after_navigation
    driver = mock("driver")
    driver.expects(:command).with("network", "requests", "--clear").returns({})
    driver.expects(:command).with("open", "https://example.test/properties").returns({})
    driver.expects(:command).with("network", "requests").returns({ "requests" => [
      { "url" => "https://example.test/api/properties", "status" => 200, "requestId" => "r1" }
    ] })
    driver.expects(:command).with("network", "request", "r1").returns({
      "url" => "https://example.test/api/properties", "status" => 200, "method" => "GET",
      "headers" => { "Authorization" => "Bearer test" }, "responseBody" => '{"data":[{"id":"p1"}]}'
    })
    captured = nil
    page = DoorLoopApp::Browser::AgentPage.new(driver, on_response: ->(response) { captured = response })
    response = page.expect_response(->(r) { r.url.end_with?("/api/properties") && r.status == 200 }) do
      page.goto("https://example.test/properties")
    end

    assert_equal "p1", JSON.parse(response.body)["data"].first["id"]
    assert_same response, captured
    assert_equal "Bearer test", response.headers["Authorization"]
  end
end
