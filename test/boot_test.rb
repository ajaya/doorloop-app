# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"
require "json"

class BootTest < Minitest::Test
  def test_stdio_entry_point_runs_from_a_clients_working_directory
    root = File.expand_path("..", __dir__)
    requests = [
      { jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "boot-test", version: "1" } } },
      { jsonrpc: "2.0", method: "notifications/initialized" },
      { jsonrpc: "2.0", id: 2, method: "tools/list" }
    ].map { |value| JSON.generate(value) }.join("\n") + "\n"
    Dir.mktmpdir("doorloop-client-cwd") do |dir|
      env = { "BUNDLE_GEMFILE" => nil, "RUBYOPT" => nil, "DOORLOOP_DB_PATH" => ":memory:",
              "DOORLOOP_ALLOW_PAID_AI" => "false", "DOORLOOP_EMAIL" => "", "DOORLOOP_PASSWORD" => "" }
      output, error, status = Open3.capture3(env, RbConfig.ruby, File.join(root, "bin/doorloop"), "server", chdir: dir, stdin_data: requests)
      assert status.success?, error
      responses = output.lines.map { |line| JSON.parse(line) }
      assert_equal 9, responses.find { |value| value["id"] == 2 }.dig("result", "tools").size
    end
  end

  def test_eager_load_and_store_work_without_an_existing_database
    script = <<~RUBY
      require "doorloop_app"
      DoorLoopApp.eager_load!
      store = DoorLoopApp::Store.new(db_path: ":memory:")
      store.upsert_properties([{ id: "boot", name: "Boot property" }])
      abort "property was not persisted" unless store.find_property("boot")[:name] == "Boot property"
    RUBY

    output, status = Open3.capture2e(RbConfig.ruby, "-Ilib", "-e", script)
    assert status.success?, output
  end
end
