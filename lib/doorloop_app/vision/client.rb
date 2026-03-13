# frozen_string_literal: true

require "anthropic"
require "json"

module DoorLoopApp
  module Vision
    class Client
      def initialize(api_key: nil, model: nil)
        config = DoorLoopApp.configuration
        @api_key = api_key || config.anthropic_api_key
        @model = model || config.vision_model
        @client = Anthropic::Client.new(access_token: @api_key)
      end

      # Extract structured data from page text (token-efficient, ~800 tokens)
      def extract_from_text(page_text:, prompt:, page_key: nil)
        system_prompt = build_system_prompt(page_key)
        response = @client.messages.create(
          model: @model,
          max_tokens: 4096,
          system: system_prompt,
          messages: [{
            role: "user",
            content: "Page text:\n#{page_text}\n\n#{prompt}"
          }]
        )
        parse_response(response)
      end

      # Extract from screenshot (more expensive, use as last resort)
      def extract_from_screenshot(screenshot_base64:, prompt:, page_key: nil)
        system_prompt = build_system_prompt(page_key)
        response = @client.messages.create(
          model: @model,
          max_tokens: 4096,
          system: system_prompt,
          messages: [{
            role: "user",
            content: [
              { type: "image", source: { type: "base64", media_type: "image/png", data: screenshot_base64 } },
              { type: "text", text: prompt }
            ]
          }]
        )
        parse_response(response)
      end

      private

      def build_system_prompt(page_key)
        <<~PROMPT
          You are a web scraping assistant for DoorLoop property management.
          Extract structured data from the provided content.
          Return a JSON object with a "data" key containing an array of objects.
          #{page_key ? "Page context: #{page_key}" : ""}
          Return ONLY valid JSON, no markdown or explanation.
        PROMPT
      end

      def parse_response(response)
        text = response.content.first.text
        # Strip markdown code fences if present
        text = text.gsub(/```json\s*/, "").gsub(/```\s*/, "").strip
        parsed = JSON.parse(text)
        VisionResult.new(data: parsed["data"] || parsed)
      rescue JSON::ParserError => e
        $stderr.puts "[Vision] Failed to parse response: #{e.message}"
        VisionResult.new(data: [])
      end
    end
  end
end
