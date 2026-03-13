# frozen_string_literal: true

require "test_helper"

class ExecutorTest < Minitest::Test
  include TestHelpers

  def test_uses_api_layer_first
    session = build_mock_session
    token_store = mock("token_store")
    token_store.stubs(:valid?).returns(true)

    api_client = mock("api_client")
    registry = mock("registry")
    registry.stubs(:endpoint).returns({ "path" => "/api/properties", "query_params" => {} })
    api_client.stubs(:registry).returns(registry)

    endpoint_instance = mock("properties_endpoint")
    endpoint_instance.expects(:list_all).returns([{ id: "1", name: "Test" }])
    DoorloopMcp::Api::Endpoints::Properties.expects(:new).with(api_client).returns(endpoint_instance)

    executor = DoorloopMcp::Data::Executor.new(
      session: session,
      api_client: api_client,
      token_store: token_store
    )

    result = executor.call(:list_properties)
    assert_equal [{ id: "1", name: "Test" }], result
  end

  def test_falls_back_to_dom_when_api_fails
    session = build_mock_session
    session.stubs(:ensure_authenticated!)

    token_store = mock("token_store")
    token_store.stubs(:valid?).returns(true)

    api_client = mock("api_client")
    registry = mock("registry")
    registry.stubs(:endpoint).returns({ "path" => "/api/properties", "query_params" => {} })
    api_client.stubs(:registry).returns(registry)

    endpoint_instance = mock("properties_endpoint")
    endpoint_instance.expects(:list_all).raises(DoorloopMcp::Api::Error.new("timeout"))
    DoorloopMcp::Api::Endpoints::Properties.expects(:new).with(api_client).returns(endpoint_instance)

    page_instance = mock("properties_page")
    page_instance.expects(:list_all).returns([{ id: "1", name: "Fallback" }])
    DoorloopMcp::Browser::Pages::PropertiesPage.stubs(:new).with(session).returns(page_instance)

    executor = DoorloopMcp::Data::Executor.new(
      session: session,
      api_client: api_client,
      token_store: token_store
    )

    result = executor.call(:list_properties)
    assert_equal [{ id: "1", name: "Fallback" }], result
  end

  def test_uses_dom_when_no_api_client
    session = build_mock_session
    session.stubs(:ensure_authenticated!)

    page_instance = mock("properties_page")
    page_instance.expects(:list_all).returns([{ id: "1", name: "DOM" }])
    DoorloopMcp::Browser::Pages::PropertiesPage.stubs(:new).with(session).returns(page_instance)

    executor = DoorloopMcp::Data::Executor.new(session: session)

    result = executor.call(:list_properties)
    assert_equal [{ id: "1", name: "DOM" }], result
  end

  def test_falls_back_to_vision_when_dom_empty
    session = build_mock_session
    session.stubs(:ensure_authenticated!)
    session.stubs(:text_content).returns("Property: Test Prop")

    page_instance = mock("properties_page")
    page_instance.stubs(:list_all).returns([])
    DoorloopMcp::Browser::Pages::PropertiesPage.stubs(:new).with(session).returns(page_instance)

    vision_client = mock("vision_client")
    vision_result = DoorloopMcp::Vision::VisionResult.new(data: [{ "name" => "Test Prop" }])
    vision_client.expects(:extract_from_text).returns(vision_result)

    executor = DoorloopMcp::Data::Executor.new(
      session: session,
      vision_client: vision_client
    )

    result = executor.call(:list_properties)
    assert_equal [{ "name" => "Test Prop" }], result
  end

  def test_returns_empty_when_all_layers_fail
    session = build_mock_session
    session.stubs(:ensure_authenticated!)

    page_instance = mock("properties_page")
    page_instance.stubs(:list_all).returns([])
    DoorloopMcp::Browser::Pages::PropertiesPage.stubs(:new).with(session).returns(page_instance)

    executor = DoorloopMcp::Data::Executor.new(session: session)

    result = executor.call(:list_properties)
    assert_equal [], result
  end

  def test_raises_for_unknown_operation
    executor = DoorloopMcp::Data::Executor.new(session: build_mock_session)
    assert_raises(ArgumentError) { executor.call(:nonexistent) }
  end

  def test_stores_properties_in_sqlite
    session = build_mock_session
    session.stubs(:ensure_authenticated!)

    store = DoorloopMcp::Store.new(db_path: ":memory:")

    page_instance = mock("properties_page")
    page_instance.expects(:list_all).returns([
      { id: "prop_1", name: "Sunset Apartments", address: "123 Main St", type: "Multi-Family", units: "12" },
      { id: "prop_2", name: "Oak Villa", address: "456 Oak Ave", type: "Condo", units: "4" }
    ])
    DoorloopMcp::Browser::Pages::PropertiesPage.stubs(:new).with(session).returns(page_instance)

    executor = DoorloopMcp::Data::Executor.new(session: session, store: store)
    result = executor.call(:list_properties)

    assert_equal 2, result.length
    assert_equal 2, store.properties_count

    prop = store.find_property("prop_1")
    assert_equal "Sunset Apartments", prop[:name]

    prop2 = store.find_property("prop_2")
    assert_equal "Oak Villa", prop2[:name]
  end

  def test_passes_params_to_layers
    session = build_mock_session
    session.expects(:ensure_authenticated!)

    page_instance = mock("units_page")
    page_instance.expects(:list_all).with(property_id: "p1").returns([{ name: "Unit 1" }])
    DoorloopMcp::Browser::Pages::UnitsPage.expects(:new).with(session).returns(page_instance)

    executor = DoorloopMcp::Data::Executor.new(session: session)

    result = executor.call(:list_units, property_id: "p1")
    assert_equal [{ name: "Unit 1" }], result
  end
end
