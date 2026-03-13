# frozen_string_literal: true

require "test_helper"

module DoorLoopApp
  module LLM
    class TenantMatcherTest < Minitest::Test
      def test_returns_matching_tenant
        tenants = [
          { id: "t1", name: "Prayag Bansal", email: "prayag@test.com", phone: "555-0001", status: "CURRENT" },
          { id: "t2", name: "Shital Agrawalla", email: "shital@test.com", phone: "555-0002", status: "CURRENT" }
        ]

        matcher = DoorLoopApp::LLM::TenantMatcher.new
        matcher.stubs(:call_llm).returns('{"id": "t1"}')
        result = matcher.find("Prayag", tenants)

        assert_equal "t1", result[:id]
        assert_equal "Prayag Bansal", result[:name]
      end

      def test_returns_nil_when_no_match
        tenants = [
          { id: "t1", name: "Prayag Bansal", email: "prayag@test.com", phone: nil, status: "CURRENT" }
        ]

        matcher = DoorLoopApp::LLM::TenantMatcher.new
        matcher.stubs(:call_llm).returns("null")
        result = matcher.find("Nonexistent Person", tenants)

        assert_nil result
      end

      def test_returns_nil_on_empty_tenants
        matcher = DoorLoopApp::LLM::TenantMatcher.new
        result = matcher.find("Anyone", [])

        assert_nil result
      end

      def test_returns_nil_on_llm_error
        tenants = [{ id: "t1", name: "Test", email: nil, phone: nil, status: "CURRENT" }]

        matcher = DoorLoopApp::LLM::TenantMatcher.new
        matcher.stubs(:call_llm).raises(RuntimeError, "connection refused")
        result = matcher.find("Test", tenants)

        assert_nil result
      end

      def test_handles_markdown_wrapped_json
        tenants = [
          { id: "t1", name: "Prayag Bansal", email: nil, phone: nil, status: "CURRENT" }
        ]

        matcher = DoorLoopApp::LLM::TenantMatcher.new
        matcher.stubs(:call_llm).returns("```json\n{\"id\": \"t1\"}\n```")
        result = matcher.find("Prayag", tenants)

        assert_equal "t1", result[:id]
      end

      def test_returns_nil_on_invalid_json
        tenants = [{ id: "t1", name: "Test", email: nil, phone: nil, status: "CURRENT" }]

        matcher = DoorLoopApp::LLM::TenantMatcher.new
        matcher.stubs(:call_llm).returns("I think the answer is t1")
        result = matcher.find("Test", tenants)

        assert_nil result
      end

    end
  end
end
