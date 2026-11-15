# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"

class BootTest < Minitest::Test
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
