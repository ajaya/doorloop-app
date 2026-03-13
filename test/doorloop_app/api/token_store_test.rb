# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TokenStoreTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("doorloop_test")
    @store = DoorLoopApp::Api::TokenStore.new(session_dir: @tmpdir)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_initially_invalid
    refute @store.valid?
    assert_nil @store.token
  end

  def test_update_stores_token
    @store.update(token: "abc123")
    assert @store.valid?
    assert_equal "abc123", @store.token
    assert_equal :bearer, @store.token_type
  end

  def test_update_with_cookie_type
    @store.update(token: "session=xyz", token_type: :cookie)
    assert @store.valid?
    assert_equal :cookie, @store.token_type
  end

  def test_invalidate_clears_token
    @store.update(token: "abc123")
    assert @store.valid?
    @store.invalidate!
    refute @store.valid?
    assert_nil @store.token
  end

  def test_auth_headers_bearer
    @store.update(token: "abc123", token_type: :bearer)
    assert_equal({ "Authorization" => "Bearer abc123" }, @store.auth_headers)
  end

  def test_auth_headers_cookie
    @store.update(token: "session=xyz", token_type: :cookie)
    assert_equal({ "Cookie" => "session=xyz" }, @store.auth_headers)
  end

  def test_auth_headers_empty_when_invalid
    assert_equal({}, @store.auth_headers)
  end

  def test_persists_to_disk
    @store.update(token: "persisted_token")

    store2 = DoorLoopApp::Api::TokenStore.new(session_dir: @tmpdir)
    assert store2.valid?
    assert_equal "persisted_token", store2.token
  end

  def test_expired_token_is_invalid
    @store.update(token: "expired", expires_at: Time.now - 60)
    refute @store.valid?
  end

  def test_future_expiry_is_valid
    @store.update(token: "fresh", expires_at: Time.now + 3600)
    assert @store.valid?
  end

  def test_empty_token_is_invalid
    @store.update(token: "")
    refute @store.valid?
  end
end
