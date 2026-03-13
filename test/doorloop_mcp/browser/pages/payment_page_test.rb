# frozen_string_literal: true

require "test_helper"
require "playwright"

module DoorloopMcp
  module Browser
    module Pages
      class PaymentPageTest < Minitest::Test
        def setup
          @session = mock("session")
          @page = mock("page")
          @session.stubs(:page).returns(@page)
          @session.stubs(:navigate)
          @page.stubs(:wait_for_selector)
          @payment_page = PaymentPage.new(@session)
        end

        def test_fill_payment_navigates_to_correct_url
          lease_id = "69b1124335cd61e24faf0551"
          expected_path = "/leases/active-leases/#{lease_id}/transactions/payment/new?period=all-time&filter_lease=#{lease_id}"

          stub_all_form_fields
          @session.expects(:navigate).with(expected_path)

          result = @payment_page.fill_payment(lease_id: lease_id, amount: "100")

          assert_equal :ready, result[:status]
          assert_equal lease_id, result[:lease_id]
        end

        def test_fill_payment_returns_form_state
          stub_all_form_fields(tenant_value: "Prayag Bansal", amount_value: "$500.00")

          result = @payment_page.fill_payment(lease_id: "abc123", amount: "500")

          assert_equal :ready, result[:status]
          assert_equal "Prayag Bansal", result[:tenant]
          assert_equal "$500.00", result[:amount]
          assert_equal "EFT", result[:payment_method]
        end

        def test_fill_payment_with_memo
          stub_all_form_fields
          memo_field = mock("memo")
          @page.stubs(:locator).with('[data-cy="DLUI-Dialog-MemoTextArea"]').returns(memo_field)
          memo_field.expects(:fill).with("March rent")

          result = @payment_page.fill_payment(lease_id: "abc123", amount: "100", memo: "March rent")

          assert_equal "March rent", result[:memo]
        end

        def test_fill_payment_with_date
          stub_all_form_fields(date_value: "01/15/2026")

          result = @payment_page.fill_payment(lease_id: "abc123", amount: "100", date: "2026-01-15")

          assert_equal :ready, result[:status]
          assert_equal "01/15/2026", result[:date]
        end

        def test_fill_payment_returns_error_on_timeout
          @page.stubs(:wait_for_selector).raises(Playwright::TimeoutError.new(message: "Timeout 10000ms"))

          result = @payment_page.fill_payment(lease_id: "abc123", amount: "100")

          assert_equal :error, result[:status]
          assert_match(/Timeout/, result[:message])
        end

        def test_skips_tenant_selection_when_already_matching
          tenant_input = stub_input("[data-cy=\"AutoCompleteInput-receivedFromTenant\"]", "Prayag Bansal")
          stub_all_form_fields(tenant_value: "Prayag Bansal")

          # Should NOT call fill on tenant input since name already matches
          tenant_input.expects(:click).never

          @payment_page.fill_payment(lease_id: "abc123", tenant_name: "Prayag", amount: "100")
        end

        private

        def stub_all_form_fields(tenant_value: "Prayag Bansal", amount_value: "$100.00", date_value: "03/11/2026")
          # Date input
          date = mock("date_input")
          date.stubs(:click)
          date.stubs(:evaluate)
          date.stubs(:fill)
          date.stubs(:press)
          date.stubs(:input_value).returns(date_value)
          @page.stubs(:locator).with('#date-pickerchargeDueDate').returns(date)

          # Amount input
          amount = mock("amount_input")
          amount.stubs(:click)
          amount.stubs(:evaluate)
          amount.stubs(:fill)
          amount.stubs(:input_value).returns(amount_value)
          @page.stubs(:locator).with('[data-cy="amountReceived"] input').returns(amount)

          # Payment method
          pm = mock("pm_input")
          pm.stubs(:click)
          pm.stubs(:fill)
          @page.stubs(:locator).with('[data-cy="AutoCompleteInput-paymentMethod"]').returns(pm)

          # Dropdown option
          option = mock("option")
          option.stubs(:click)
          option_list = mock("option_list")
          option_list.stubs(:first).returns(option)
          @page.stubs(:locator).with('[role="option"]').returns(option_list)

          # Tenant read
          tenant = mock("tenant_read")
          tenant.stubs(:input_value).returns(tenant_value)
          @page.stubs(:locator).with('[data-cy="AutoCompleteInput-receivedFromTenant"]').returns(tenant)
        end

        def stub_input(selector, value)
          input = mock("input_#{selector}")
          input.stubs(:input_value).returns(value)
          input.stubs(:click)
          input.stubs(:evaluate)
          input.stubs(:fill)
          @page.stubs(:locator).with(selector).returns(input)
          input
        end
      end
    end
  end
end
