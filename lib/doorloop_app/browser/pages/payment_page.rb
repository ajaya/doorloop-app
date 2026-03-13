# frozen_string_literal: true

module DoorLoopApp
  module Browser
    module Pages
      class PaymentPage < PageObject
        PAYMENT_PATH = "/leases/active-leases/%s/transactions/payment/new?period=all-time&filter_lease=%s"

        SELECTORS = {
          dialog:          '[data-cy="Dialog-Container"]',
          lease_selector:  '[data-cy="EntitySelector-Lease"]',
          tenant_input:    '[data-cy="AutoCompleteInput-receivedFromTenant"]',
          deposit_input:   '[data-cy="AutoCompleteInput-depositToAccount"]',
          date_input:      '#date-pickerchargeDueDate',
          amount_input:    '[data-cy="amountReceived"] input',
          payment_method:  '[data-cy="AutoCompleteInput-paymentMethod"]',
          memo_textarea:   '[data-cy="DLUI-Dialog-MemoTextArea"]',
          save_button:     '[data-cy="Action-Button-Save"]',
          cancel_button:   '[data-cy="Action-Button-Cancel"]',
          close_button:    '[data-cy="Dialog-X-Button"]'
        }.freeze

        # Navigate to payment form for a lease and fill it out.
        # Does NOT click Save — returns form state for user confirmation.
        def fill_payment(lease_id: nil, tenant_name: nil, amount:, date: nil, payment_method: "EFT", memo: nil)
          lease_id = resolve_lease_id(lease_id, tenant_name)
          navigate_to(PAYMENT_PATH % [lease_id, lease_id])
          wait_for_dialog

          select_tenant(tenant_name) if tenant_name
          fill_date(date) if date
          fill_amount(amount)
          select_payment_method(payment_method)
          fill_memo(memo) if memo

          # Return current form state
          {
            status: :ready,
            lease_id: lease_id,
            tenant: read_tenant_value,
            date: read_date_value,
            amount: read_amount_value,
            payment_method: payment_method,
            memo: memo,
            message: "Payment form filled. Review and click Save to confirm."
          }
        rescue => e
          log "Payment form failed: #{e.message}"
          { status: :error, message: e.message }
        end

        private

        def resolve_lease_id(lease_id, tenant_name)
          return lease_id if lease_id

          raise ArgumentError, "Either lease_id or tenant_name is required" unless tenant_name

          tenant = find_tenant(tenant_name)
          raise ArgumentError, "Tenant '#{tenant_name}' not found" unless tenant

          id = tenant[:lease]&.to_s
          raise ArgumentError, "No lease found for tenant '#{tenant_name}'" if id.nil? || id.empty?

          log "Resolved tenant '#{tenant_name}' → lease #{id}"
          id
        end

        def find_tenant(name)
          store = DoorLoopApp.store

          # Layer 1: DB name search
          results = store.find_tenant_by_name(name)
          return results.first if results.any?

          # Layer 2: Refresh data and retry
          DoorLoopApp.executor.call(:list_tenants)
          results = store.find_tenant_by_name(name)
          return results.first if results.any?

          # Layer 3: LLM fuzzy match against all tenants
          log "DB search failed for '#{name}', trying LLM match..."
          all_tenants = store.all_tenants
          return nil if all_tenants.empty?

          matcher = DoorLoopApp::LLM::TenantMatcher.new
          match = matcher.find(name, all_tenants)
          if match
            log "LLM matched '#{name}' → #{match[:name]} (#{match[:id]})"
          else
            log "LLM could not match '#{name}'"
          end
          match
        end

        def wait_for_dialog
          page.wait_for_selector(SELECTORS[:dialog], timeout: 10_000)
          sleep 1 # Let form fields populate
        end

        def select_tenant(name)
          input = page.locator(SELECTORS[:tenant_input])
          current = input.input_value.to_s.strip

          # Skip if already showing the right tenant
          return if current.downcase.include?(name.downcase)

          log "Selecting tenant: #{name} (current: #{current})"
          input.click
          sleep 0.3
          input.evaluate("el => el.select()")
          input.fill("")
          sleep 0.3
          input.fill(name)
          sleep 1

          # Pick the first matching option
          option = page.locator('[role="option"]').first
          if option
            option.click
            sleep 0.5
          else
            log "No dropdown option found for '#{name}', leaving typed value"
          end
        end

        def fill_date(date)
          formatted = resolve_date(date)
          input = page.locator(SELECTORS[:date_input])
          input.click
          sleep 0.2
          input.evaluate("el => el.select()")
          input.fill("")
          sleep 0.2
          input.fill(formatted)
          sleep 0.3
          # Press Tab to dismiss any date picker popup
          input.press("Tab")
          sleep 0.3
        end

        # Accepts:
        #   "today" / "now"                → today's date
        #   "yesterday"                    → yesterday
        #   "YYYY-MM-DD"                   → converts to MM/DD/YYYY
        #   "MM/DD/YYYY" or other formats  → passed through as-is
        def resolve_date(date)
          require "date"
          str = date.to_s.strip.downcase
          d = case str
              when "today", "now"   then Date.today
              when "yesterday"      then Date.today - 1
              else                       nil
              end
          if d
            d.strftime("%m/%d/%Y")
          elsif date.match?(%r{\A\d{4}-\d{2}-\d{2}\z})
            parts = date.split("-")
            "#{parts[1]}/#{parts[2]}/#{parts[0]}"
          else
            date
          end
        end

        def fill_amount(amount)
          input = page.locator(SELECTORS[:amount_input])
          input.click
          sleep 0.2
          input.evaluate("el => el.select()")
          input.fill("")
          sleep 0.2
          input.fill(amount.to_s.gsub(/[^0-9.]/, ""))
          sleep 0.3
        end

        def select_payment_method(method)
          input = page.locator(SELECTORS[:payment_method])
          input.click
          sleep 0.5

          # Type to filter
          input.fill(method)
          sleep 0.5

          option = page.locator('[role="option"]').first
          if option
            option.click
            sleep 0.3
          else
            log "Payment method '#{method}' not found in dropdown"
          end
        end

        def fill_memo(text)
          memo = page.locator(SELECTORS[:memo_textarea])
          memo.fill(text)
        end

        def read_tenant_value
          page.locator(SELECTORS[:tenant_input]).input_value rescue nil
        end

        def read_date_value
          page.locator(SELECTORS[:date_input]).input_value rescue nil
        end

        def read_amount_value
          page.locator(SELECTORS[:amount_input]).input_value rescue nil
        end
      end
    end
  end
end
