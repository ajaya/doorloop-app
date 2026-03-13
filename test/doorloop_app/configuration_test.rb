# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @original_env = ENV.to_hash
  end

  def teardown
    ENV.replace(@original_env)
    DoorLoopApp.instance_variable_set(:@configuration, nil)
  end

  def test_reads_email_from_env
    ENV["DOORLOOP_EMAIL"] = "test@example.com"
    config = DoorLoopApp::Configuration.new
    assert_equal "test@example.com", config.email
  end

  def test_reads_password_from_env
    ENV["DOORLOOP_PASSWORD"] = "secret123"
    config = DoorLoopApp::Configuration.new
    assert_equal "secret123", config.password
  end

  def test_default_url
    ENV.delete("DOORLOOP_URL")
    config = DoorLoopApp::Configuration.new
    assert_equal "https://bansals.app.doorloop.com", config.url
  end

  def test_custom_url
    ENV["DOORLOOP_URL"] = "https://custom.app.doorloop.com"
    config = DoorLoopApp::Configuration.new
    assert_equal "https://custom.app.doorloop.com", config.url
  end

  def test_validate_raises_without_email
    ENV.delete("DOORLOOP_EMAIL")
    ENV["DOORLOOP_PASSWORD"] = "pass"
    config = DoorLoopApp::Configuration.new
    assert_raises(RuntimeError) { config.validate! }
  end

  def test_validate_raises_without_password
    ENV["DOORLOOP_EMAIL"] = "test@example.com"
    ENV.delete("DOORLOOP_PASSWORD")
    config = DoorLoopApp::Configuration.new
    assert_raises(RuntimeError) { config.validate! }
  end

  def test_validate_passes_with_both_credentials
    ENV["DOORLOOP_EMAIL"] = "test@example.com"
    ENV["DOORLOOP_PASSWORD"] = "pass"
    config = DoorLoopApp::Configuration.new
    config.validate! # Should not raise
  end

  def test_default_db_path
    ENV.delete("DOORLOOP_DB_PATH")
    config = DoorLoopApp::Configuration.new
    assert_equal File.join(File.expand_path("~/.doorloop-mcp"), "doorloop.sqlite3"), config.db_path
  end

  def test_custom_db_path
    ENV["DOORLOOP_DB_PATH"] = "/tmp/test.sqlite3"
    config = DoorLoopApp::Configuration.new
    assert_equal "/tmp/test.sqlite3", config.db_path
  end

  def test_default_profile_dir
    ENV.delete("DOORLOOP_PROFILE_DIR")
    config = DoorLoopApp::Configuration.new
    assert_equal File.expand_path("~/.doorloop-mcp/chrome-profile"), config.profile_dir
  end

  def test_custom_profile_dir
    ENV["DOORLOOP_PROFILE_DIR"] = "/tmp/my-chrome-profile"
    config = DoorLoopApp::Configuration.new
    assert_equal "/tmp/my-chrome-profile", config.profile_dir
  end

  def test_agentmail_configured_when_both_set
    ENV["AGENTMAIL_API_KEY"] = "key"
    ENV["AGENTMAIL_INBOX_ID"] = "inbox_123"
    config = DoorLoopApp::Configuration.new
    assert config.agentmail_configured?
  end

  def test_agentmail_not_configured_without_key
    ENV.delete("AGENTMAIL_API_KEY")
    ENV["AGENTMAIL_INBOX_ID"] = "inbox_123"
    config = DoorLoopApp::Configuration.new
    refute config.agentmail_configured?
  end

  def test_agentmail_not_configured_without_inbox
    ENV["AGENTMAIL_API_KEY"] = "key"
    ENV.delete("AGENTMAIL_INBOX_ID")
    config = DoorLoopApp::Configuration.new
    refute config.agentmail_configured?
  end

  def test_default_headless
    ENV.delete("DOORLOOP_HEADLESS")
    config = DoorLoopApp::Configuration.new
    assert config.headless
  end

  def test_headless_false
    ENV["DOORLOOP_HEADLESS"] = "false"
    config = DoorLoopApp::Configuration.new
    refute config.headless
  end
end
