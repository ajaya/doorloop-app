# frozen_string_literal: true

module DoorloopMcp
  # Single backend shared by both MCP tools and CLI commands.
  # Owns all business logic: offline/refresh decisions, LLM fallback,
  # payment confirmation, and email sending.
  # CLI/MCP are responsible only for browser lifecycle and formatting.
  class Service
    def initialize(executor:, store:)
      @executor = executor
      @store    = store
    end

    # --- Properties ---

    def list_properties(refresh: false)
      @executor.call(:list_properties) if refresh
      @store.all_properties
    end

    # --- Units ---

    def list_units(property_id: nil, refresh: false)
      @executor.call(:list_units) if refresh
      property_id ? @store.units_for_property(property_id) : @store.all_units
    end

    # --- Tenants ---

    def list_tenants(property_id: nil, refresh: false)
      @executor.call(:list_tenants) if refresh
      property_id ? @store.tenants_for_property(property_id) : @store.all_tenants
    end

    # DB LIKE search → LLM fuzzy fallback.
    # Pass refresh: true to fetch from DoorLoop before searching.
    def find_tenant(query, refresh: false)
      @executor.call(:list_tenants) if refresh
      results = @store.find_tenant_by_name(query)
      if results.empty?
        match = LLM::TenantMatcher.new.find(query, @store.all_tenants)
        results = [match].compact
      end
      results
    end

    # --- Leases ---

    def list_leases(property_id: nil, refresh: false)
      @executor.call(:list_leases) if refresh
      property_id ? @store.leases_for_property(property_id) : @store.all_leases
    end

    # --- Lease Transactions (always requires browser) ---

    def list_lease_transactions(lease_id:)
      @executor.call(:list_lease_transactions, lease_id: lease_id)
    end

    # --- Payment (always requires browser) ---

    def receive_payment(lease_id: nil, tenant_name: nil, amount:, date: nil, payment_method: "EFT", memo: nil)
      @executor.call(:receive_payment,
        lease_id:       lease_id,
        tenant_name:    tenant_name,
        amount:         amount,
        date:           date,
        payment_method: payment_method,
        memo:           memo
      )
    end

    # Navigate to transactions page, find those matching amount, store them.
    def confirm_payment(lease_id:, amount:)
      all_txns = list_lease_transactions(lease_id: lease_id)
      @store.upsert_lease_transactions(all_txns) if all_txns.any?
      target = amount.to_s.gsub(/[^0-9.]/, "").to_f
      all_txns.select { |t| (t["totalAmount"] || t[:totalAmount]).to_f == target }.first(5)
    end

    # Send confirmation email via AgentMail.
    # Returns { sent: true, to: "..." } or { sent: false, reason: :not_configured }.
    def send_payment_confirmation(transactions:, tenant_name:)
      config = DoorloopMcp.configuration
      return { sent: false, reason: :not_configured } unless config.email_notifications_configured?

      Notifications::PaymentConfirmation.send!(
        transactions: transactions,
        tenant_name:  tenant_name,
        config:       config
      )
      { sent: true, to: config.confirmation_email_to }
    end
  end
end
