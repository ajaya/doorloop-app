# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class RegistryTest < Minitest::Test
  def test_records_post_based_read_routes_with_their_search_body
    registry = DoorLoopApp::Api::Registry.new(path: File.join(@tmpdir, "post.json"))
    response = DoorLoopApp::Browser::Response.new(
      url: "#{DoorLoopApp.configuration.url}/api/properties/custom-fields",
      status: 200, method: "POST", body: '{"data":[]}',
      headers: { "tokenId" => "private-token" },
      request_body: '{"filter_active":"true","page_number":1,"page_size":50}'
    )
    registry.record_response(response)
    entry = DoorLoopApp::Api::Registry.new(path: File.join(@tmpdir, "post.json")).endpoint("list_properties")
    assert_equal "POST", entry["method"]
    assert_equal({ "filter_active" => "true", "page_number" => 1, "page_size" => 50 }, entry["request_body"])
    refute_includes File.read(File.join(@tmpdir, "post.json")), "private-token"
  end

  def test_records_discovered_routes_without_persisting_authentication
    Dir.mktmpdir("registry") do |dir|
      path = File.join(dir, "registry.json")
      registry = DoorLoopApp::Api::Registry.new(path: path)
      response = DoorLoopApp::Browser::Response.new(
        url: "#{DoorLoopApp.configuration.url}/api/leases/tenants/custom-fields?period=all-time&token=secret",
        status: 200, method: "GET", body: '{"data":[]}', headers: { "Authorization" => "Bearer secret" }
      )
      registry.record_response(response)
      endpoint = DoorLoopApp::Api::Registry.new(path: path).endpoint("list_tenants")
      assert_equal "/api/leases/tenants/custom-fields", endpoint["path"]
      assert_equal({ "period" => "all-time" }, endpoint["query_params"])
      refute_includes File.read(path), "secret"
      assert_equal 0o600, File.stat(path).mode & 0o777
    end
  end

  def setup
    @tmpdir = Dir.mktmpdir("doorloop_test")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_empty_when_file_missing
    registry = DoorLoopApp::Api::Registry.new(path: File.join(@tmpdir, "missing.json"))
    refute registry.discovered?
    assert_equal({}, registry.endpoints)
  end

  def test_loads_registry_from_file
    path = File.join(@tmpdir, "api_registry.json")
    File.write(path, JSON.generate({
      "base_url" => "https://api.doorloop.com",
      "endpoints" => {
        "list_properties" => { "path" => "/api/properties", "method" => "GET" }
      }
    }))

    registry = DoorLoopApp::Api::Registry.new(path: path)
    assert registry.discovered?
    assert_equal "https://api.doorloop.com", registry.base_url
    assert_equal({ "path" => "/api/properties", "method" => "GET" }, registry.endpoint("list_properties"))
  end

  def test_discovered_false_with_empty_endpoints
    path = File.join(@tmpdir, "api_registry.json")
    File.write(path, JSON.generate({ "endpoints" => {} }))

    registry = DoorLoopApp::Api::Registry.new(path: path)
    refute registry.discovered?
  end

  def test_handles_invalid_json
    path = File.join(@tmpdir, "api_registry.json")
    File.write(path, "not json")

    registry = DoorLoopApp::Api::Registry.new(path: path)
    refute registry.discovered?
  end

  def test_endpoint_returns_nil_for_unknown
    path = File.join(@tmpdir, "api_registry.json")
    File.write(path, JSON.generate({ "endpoints" => {} }))

    registry = DoorLoopApp::Api::Registry.new(path: path)
    assert_nil registry.endpoint("nonexistent")
  end
end
