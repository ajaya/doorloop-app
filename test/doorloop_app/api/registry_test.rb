# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class RegistryTest < Minitest::Test
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
