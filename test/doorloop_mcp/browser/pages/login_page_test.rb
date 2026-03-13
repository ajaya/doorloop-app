# frozen_string_literal: true

require "test_helper"

class LoginPageTest < Minitest::Test
  include TestHelpers

  def test_login_navigates_fills_and_submits
    session = build_mock_session
    mock_page = session.page

    # Navigate to login URL
    mock_page.expects(:goto).with("https://app.doorloop.com/auth/login", waitUntil: "domcontentloaded")

    # After navigation, still on auth page
    session.stubs(:current_url).returns(
      "https://app.doorloop.com/auth/login"
    ).then.returns(
      "https://app.doorloop.com/auth/login"
    ).then.returns(
      "https://bansals.app.doorloop.com/dashboard"
    )

    # Fill email, password, click sign in
    mock_page.expects(:fill).with("#email", "test@example.com")
    mock_page.expects(:fill).with("#password", "secret")
    mock_page.expects(:click).with('[data-cy="signIn"]')

    # text_content for two_factor_page? check
    session.stubs(:text_content).returns("Sign In page")

    login_page = DoorloopMcp::Browser::Pages::LoginPage.new(session)
    login_page.stubs(:sleep)
    login_page.login("test@example.com", "secret")
  end

  def test_login_skips_when_already_logged_in
    session = build_mock_session
    mock_page = session.page

    # Navigate to login URL
    mock_page.expects(:goto).with("https://app.doorloop.com/auth/login", waitUntil: "domcontentloaded")

    # Already logged in — URL is dashboard (no /auth)
    session.stubs(:current_url).returns("https://bansals.app.doorloop.com/dashboard")

    # Should NOT try to fill credentials
    mock_page.expects(:fill).never
    mock_page.expects(:click).with('[data-cy="signIn"]').never

    login_page = DoorloopMcp::Browser::Pages::LoginPage.new(session)
    login_page.stubs(:sleep)
    result = login_page.login("test@example.com", "secret")

    assert_equal :logged_in, result[:status]
  end
end
