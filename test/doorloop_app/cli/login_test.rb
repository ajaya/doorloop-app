# frozen_string_literal: true

require "test_helper"
require "stringio"

class LoginCommandTest < Minitest::Test
  def test_manual_login_uses_a_visible_browser_and_verifies_the_session
    config = DoorLoopApp::Configuration.new
    config.email = config.password = nil
    DoorLoopApp.stubs(:configuration).returns(config)
    session = mock("session")
    DoorLoopApp.stubs(:session).returns(session)
    session.expects(:start)
    session.expects(:navigate).with(config.url)
    session.expects(:confirm_authenticated!)
    session.expects(:stop)
    previous_stdin = $stdin
    $stdin = StringIO.new("\n")

    capture_io { DoorLoopApp::CLI::Main.start(["login", "--manual"]) }
    refute config.headless
  ensure
    $stdin = previous_stdin
  end
end
