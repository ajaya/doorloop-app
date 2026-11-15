# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class AgentBrowserTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("doorloop-driver")
    @config = DoorLoopApp::Configuration.new
    @config.profile_dir = File.join(@dir, "profile")
    @config.agent_browser_path = "/usr/local/bin/agent-browser"
    @driver = DoorLoopApp::Browser::AgentBrowser.new(config: @config)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_runs_commands_locally_with_a_stable_persistent_profile_and_private_stdin
    secret = "a password with $(shell) and quotes '\""
    ENV["AGENT_BROWSER_PROVIDER"] = "browserbase"
    status = stub(success?: true)
    Open3.expects(:capture3).with do |env, *args, **options|
      assert_nil env["AGENT_BROWSER_PROVIDER"]
      assert_equal({}, JSON.parse(File.read(args[args.index("--config") + 1])))
      assert_includes args, @config.profile_dir
      assert_includes args, "--no-auto-connect"
      assert_equal "", args[args.index("--provider") + 1]
      refute_includes args.join(" "), secret
      assert_equal [["fill", "#password", "--", secret]], JSON.parse(options[:stdin_data])
      true
    end.returns(['[{"success":true,"result":{"filled":true}}]', "", status])

    assert_equal({ "filled" => true }, @driver.command("fill", "#password", "--", secret))
    assert_equal @driver.session_name, DoorLoopApp::Browser::AgentBrowser.new(config: @config).session_name
  ensure
    ENV.delete("AGENT_BROWSER_PROVIDER")
  end

  def test_command_errors_do_not_expose_typed_values
    Open3.stubs(:capture3).returns([
      '[{"success":false,"error":"password secret123 rejected"}]', "", stub(success?: false)
    ])
    error = assert_raises(DoorLoopApp::Browser::Error) { @driver.command("fill", "#password", "secret123") }
    refute_includes error.message, "secret123"
  end
end
