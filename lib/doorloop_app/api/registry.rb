# frozen_string_literal: true

require "json"
require "uri"
require "fileutils"

module DoorLoopApp
  module Api
    class Registry
      attr_reader :data

      def initialize(path: nil)
        @path = path || DoorLoopApp.configuration.api_registry_path
        @data = load_registry
      end

      def endpoint(name)
        @data.dig("endpoints", name.to_s)
      end

      def auth_config
        @data["auth"] || {}
      end

      def base_url
        @data["base_url"] || DoorLoopApp.configuration.url
      end

      def endpoints
        @data["endpoints"] || {}
      end

      def discovered?
        @data.key?("endpoints") && !endpoints.empty?
      end

      # Persist only known read-route metadata. Browser cookies and captured headers stay
      # in Chrome/the current process and never enter this file.
      def record_response(response)
        return unless %w[GET POST].include?(response.method) && response.status == 200
        return if response.method == "POST" && response.request_body.nil?

        uri = URI.parse(response.url)
        base = URI.parse(DoorLoopApp.configuration.url)
        return unless [uri.scheme, uri.host, uri.port] == [base.scheme, base.host, base.port]
        return if uri.path.include?("widgets")

        name = case uri.path
               when %r{\A/api/properties/custom-fields} then "list_properties"
               when %r{\A/api/units/leases/custom-fields} then "list_units"
               when %r{\A/api/leases/tenants/.*custom-fields} then "list_tenants"
               when %r{\A/api/reports/lease-accounts-receivable/} then "list_lease_transactions"
               when %r{\A/api/leases/} then "list_leases" if uri.query.to_s.include?("filter_status")
               end
        return unless name

        params = URI.decode_www_form(uri.query || "").reject { |key, _| key.match?(/token|password|secret|authorization|session|cookie/i) }.to_h
        entry = { "path" => uri.path, "query_params" => params, "response_shape" => { "data_key" => "data" } }
        entry["method"] = response.method
        if response.method == "POST"
          body = response.request_body.is_a?(String) ? JSON.parse(response.request_body) : response.request_body
          return unless body.is_a?(Hash)

          entry["request_body"] = without_credentials(body)
        end
        return if endpoint(name) == entry

        @data["endpoints"] ||= {}
        @data["endpoints"][name] = entry
        FileUtils.mkdir_p(File.dirname(@path))
        temporary = "#{@path}.#{Process.pid}.tmp"
        metadata = { "endpoints" => endpoints.transform_values do |route|
          route.slice("path", "method", "request_body", "response_shape").merge("query_params" => (route["query_params"] || {}).reject do |key, _|
            key.match?(/token|password|secret|authorization|session|cookie/i)
          end)
        end }
        File.open(temporary, File::WRONLY | File::CREAT | File::TRUNC, 0o600) { |file| file.write(JSON.pretty_generate(metadata)) }
        File.rename(temporary, @path)
      rescue URI::InvalidURIError, JSON::ParserError, SystemCallError => e
        warn "Could not save discovered API route (#{e.class})"
      end

      private

      def without_credentials(value)
        case value
        when Hash
          value.reject { |key, _| key.match?(/token|password|secret|authorization|session|cookie/i) }
               .transform_values { |item| without_credentials(item) }
        when Array then value.map { |item| without_credentials(item) }
        else value
        end
      end

      def load_registry
        return {} unless File.exist?(@path)

        JSON.parse(File.read(@path))
      rescue JSON::ParserError => e
        $stderr.puts "Warning: Could not parse api_registry.json: #{e.message}"
        {}
      end
    end
  end
end
