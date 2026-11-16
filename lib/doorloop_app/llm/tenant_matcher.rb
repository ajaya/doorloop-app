# frozen_string_literal: true

require "anthropic"
require "json"

module DoorLoopApp
  module LLM
    class TenantMatcher
      DEFAULT_MODEL = "claude-haiku-5-5"

      def initialize(model: nil)
        @model = model || DoorLoopApp.configuration.llm_model
      end

      # Given a search query and all tenants, ask LLM to find the best match.
      # Returns the matched tenant hash or nil.
      def find(query, tenants)
        return nil unless DoorLoopApp.configuration.vision_configured?
        return nil if tenants.empty?

        tenant_list = tenants.map { |t|
          { id: t[:id], name: t[:name], email: t[:email], phone: t[:phone], status: t[:status] }
        }

        prompt = <<~PROMPT
          Find the tenant that best matches the search query. Return ONLY a JSON object with the matching tenant's "id" field, or null if no match.

          Search query: "#{query}"

          Tenants:
          #{JSON.pretty_generate(tenant_list)}

          Respond with ONLY valid JSON, no markdown, no explanation. Example: {"id": "abc123"} or null
        PROMPT

        parse_response(call_llm(prompt), tenants)
      rescue => e
        $stderr.puts "[TenantMatcher] LLM search failed: #{e.message}"
        nil
      end

      private

      def call_llm(prompt)
        client = Anthropic::Client.new(api_key: DoorLoopApp.configuration.anthropic_api_key)
        response = client.messages.create(
          model: @model,
          max_tokens: 1024,
          cache_control: { type: "ephemeral" },
          messages: [{ role: "user", content: prompt }]
        )
        response.content.select { |block| block.type.to_s == "text" }.map(&:text).join("\n")
      end

      def parse_response(content, tenants)
        cleaned = content.to_s.strip
          .gsub(/\A```json\s*/, "")
          .gsub(/\s*```\z/, "")
          .strip

        return nil if cleaned == "null" || cleaned.empty?

        result = JSON.parse(cleaned, symbolize_names: true)
        return nil unless result.is_a?(Hash) && result[:id]

        tenants.find { |t| t[:id].to_s == result[:id].to_s }
      rescue JSON::ParserError
        nil
      end
    end
  end
end
