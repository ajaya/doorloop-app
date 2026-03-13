# frozen_string_literal: true

require "test_helper"

class ReceivePaymentToolTest < Minitest::Test
  include TestHelpers

  def test_returns_ready_response_on_success
    session = mock("session")
    session.stubs(:ensure_authenticated!)

    service = mock("service")
    service.expects(:receive_payment).with(
      tenant_name: "Prayag", amount: "1200",
      date: nil, payment_method: "EFT", memo: nil
    ).returns({
      status: :ready,
      tenant: "Prayag Bansal",
      lease_id: "lease123",
      date: "03/11/2026",
      amount: "$1200.00",
      payment_method: "EFT",
      memo: nil
    })

    server = build_test_server(session: session, service: service)
    DoorLoopApp::Tools::ReceivePaymentTool.register(server)
    result = call_tool(server, "doorloop_receive_payment", {
      "tenant_name" => "Prayag",
      "amount" => "1200"
    })

    refute result[:isError]
    assert_match(/ready_for_review/, result[:content].first[:text])
    assert_match(/Prayag Bansal/, result[:content].first[:text])
  end

  def test_returns_error_when_fill_fails
    session = mock("session")
    session.stubs(:ensure_authenticated!)

    service = mock("service")
    service.expects(:receive_payment).returns({
      status: :error,
      message: "Tenant not found: Unknown Person"
    })

    server = build_test_server(session: session, service: service)
    DoorLoopApp::Tools::ReceivePaymentTool.register(server)
    result = call_tool(server, "doorloop_receive_payment", {
      "tenant_name" => "Unknown Person",
      "amount" => "500"
    })

    assert result[:isError]
    assert_match(/Tenant not found/, result[:content].first[:text])
  end

  def test_returns_error_on_exception
    session = mock("session")
    session.stubs(:ensure_authenticated!).raises(RuntimeError, "not authenticated")

    service = mock("service")

    server = build_test_server(session: session, service: service)
    DoorLoopApp::Tools::ReceivePaymentTool.register(server)
    result = call_tool(server, "doorloop_receive_payment", {
      "tenant_name" => "Prayag",
      "amount" => "500"
    })

    assert result[:isError]
    assert_match(/not authenticated/, result[:content].first[:text])
  end

  def test_passes_all_params_to_service
    session = mock("session")
    session.stubs(:ensure_authenticated!)

    service = mock("service")
    service.expects(:receive_payment).with(
      tenant_name: "Prayag",
      amount: "1500",
      date: "2026-03-01",
      payment_method: "Check",
      memo: "March rent"
    ).returns({ status: :ready, tenant: "Prayag Bansal", lease_id: "l1",
                date: "03/01/2026", amount: "$1500.00",
                payment_method: "Check", memo: "March rent" })

    server = build_test_server(session: session, service: service)
    DoorLoopApp::Tools::ReceivePaymentTool.register(server)
    call_tool(server, "doorloop_receive_payment", {
      "tenant_name" => "Prayag",
      "amount" => "1500",
      "date" => "2026-03-01",
      "payment_method" => "Check",
      "memo" => "March rent"
    })
  end
end
