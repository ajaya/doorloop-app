# frozen_string_literal: true

module DoorLoopApp
  module Data
    class Executor
      OPERATIONS = {
        list_properties: {
          api_class: "Api::Endpoints::Properties",
          api_method: :list_all,
          page_class: "Browser::Pages::PropertiesPage",
          page_method: :list_all,
          vision_prompt: "Extract all properties. For each: id, name, address, type, unit count."
        },
        list_units: {
          api_class: "Api::Endpoints::Units",
          api_method: :list_all,
          page_class: "Browser::Pages::UnitsPage",
          page_method: :list_all,
          vision_prompt: "Extract all units. For each: name, status, rent, tenant."
        },
        list_tenants: {
          api_class: "Api::Endpoints::Tenants",
          api_method: :list_all,
          page_class: "Browser::Pages::TenantsPage",
          page_method: :list_all,
          vision_prompt: "Extract all tenants. For each: name, email, phone, property."
        },
        find_tenant: {
          api_class: "Api::Endpoints::Tenants",
          api_method: :search,
          page_class: nil,
          page_method: nil,
          vision_prompt: "Find the tenant matching the search. For each: id, name, email, phone, property."
        },
        list_leases: {
          api_class: "Api::Endpoints::Leases",
          api_method: :list_all,
          page_class: "Browser::Pages::LeasesPage",
          page_method: :list_all,
          vision_prompt: "Extract all leases. For each: tenant, property, unit, dates, rent, status, balance."
        },
        receive_payment: {
          api_class: nil,
          api_method: nil,
          page_class: "Browser::Pages::PaymentPage",
          page_method: :fill_payment,
          vision_prompt: nil
        },
        list_lease_transactions: {
          api_class: nil,
          api_method: nil,
          page_class: "Browser::Pages::LeaseTransactionsPage",
          page_method: :list_all,
          vision_prompt: "Extract all transactions. For each: id, type, amount, date, description, status."
        }
      }.freeze

      # Maps operations to their model class for persistence
      STORAGE = {
        list_properties: "Models::Property",
        list_units: "Models::Unit",
        list_leases: "Models::Lease",
        list_tenants: "Models::Tenant",
        list_lease_transactions: "Models::LeaseTransaction"
      }.freeze

      def initialize(session:, api_client: nil, token_store: nil, vision_client: nil, store: nil)
        @session = session
        @api_client = api_client
        @token_store = token_store
        @vision_client = vision_client
        @store = store
      end

      def call(operation, **params)
        config = OPERATIONS.fetch(operation) do
          raise ArgumentError, "Unknown operation: #{operation}"
        end

        # Layer 1: Direct API
        if @api_client && @token_store&.valid? && config[:api_class]
          result = try_api(config, **params)
          return validate_and_store(operation, result) if result
        end

        # Layer 2: Playwright DOM scraping
        @session.ensure_authenticated!
        result = try_snapshot(config, **params)
        return validate_and_store(operation, result) if result && (result.is_a?(String) || !result.empty?)

        # Layer 3: Claude AI + page text (if configured)
        if @vision_client && config[:vision_prompt]
          result = try_vision(config, **params)
          return validate_and_store(operation, result) if result && !result.empty?
        end

        # If all layers return empty, return empty rather than raising
        result || []
      end

      private

      def try_api(config, **params)
        klass = resolve_class(config[:api_class])
        endpoint = klass.new(@api_client)
        endpoint.send(config[:api_method], **params)
      rescue Api::AuthenticationError
        $stderr.puts "[Executor] API auth failed, re-authenticating..."
        refresh_token
        begin
          klass = resolve_class(config[:api_class])
          endpoint = klass.new(@api_client)
          endpoint.send(config[:api_method], **params)
        rescue => e
          $stderr.puts "[Executor] API retry failed: #{e.message}"
          nil
        end
      rescue => e
        $stderr.puts "[Executor] API call failed (#{e.class}: #{e.message}), falling back to DOM"
        nil
      end

      def try_snapshot(config, **params)
        klass = resolve_class(config[:page_class])
        page_obj = klass.new(@session)
        page_obj.send(config[:page_method], **params)
      rescue => e
        $stderr.puts "[Executor] DOM scraping failed: #{e.message}"
        nil
      end

      def try_vision(config, **params)
        page_text = @session.text_content.to_s

        return nil if page_text.empty?

        result = @vision_client.extract_from_text(
          page_text: page_text,
          prompt: config[:vision_prompt],
          page_key: config[:page_class]
        )
        result.data
      rescue => e
        $stderr.puts "[Executor] Vision fallback failed: #{e.message}"
        nil
      end

      def refresh_token
        @token_store&.invalidate!
        @session.authenticate!
        token_data = @session.extract_auth_tokens
        if token_data
          @token_store&.update(token: token_data[:token], token_type: :bearer)
        end
      end

      def validate_and_store(operation, result)
        model_name = STORAGE[operation]
        return result unless model_name && @store && result.is_a?(Array)

        model_class = resolve_class(model_name)
        id_field = model_class.const_defined?(:ID_FIELD) ? model_class.const_get(:ID_FIELD) : "id"
        items_with_id = result.select do |item|
          h = item.is_a?(Hash) ? item : item.to_h
          h[id_field] || h[id_field.to_sym] || h["id"] || h[:id]
        end
        if items_with_id.any?
          model_class.upsert_all(items_with_id)
          $stderr.puts "[Executor] Stored #{items_with_id.size} #{operation} records in SQLite"
        end

        result
      rescue => e
        $stderr.puts "[Executor] Store failed: #{e.message}"
        result
      end

      def resolve_class(class_name)
        class_name.split("::").inject(DoorLoopApp) { |mod, name| mod.const_get(name) }
      end
    end
  end
end
