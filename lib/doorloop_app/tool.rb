# frozen_string_literal: true

require "mcp"
require "json"

module DoorLoopApp
  # Base class for tool modules. Subclasses use the .tool DSL to declare MCP tools,
  # then call .mcp_tools to get MCP::Tool instances for server initialization,
  # or .register(server) to register them on an existing MCP::Server.
  #
  # Example:
  #   class MyTool < DoorLoopApp::Tool
  #     tool "doorloop_my_tool",
  #       description: "Does something",
  #       input_schema: { properties: { name: { type: "string" } }, required: ["name"] } do |args, server_context|
  #       text_response(server_context[:service].do_something(args["name"]))
  #     end
  #   end
  class Tool
    class << self
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@tools, [])
      end

      def tools
        @tools ||= []
      end

      def tool(name, description:, input_schema: {}, &handler)
        tools << {
          name:,
          description:,
          input_schema: normalize_schema(input_schema),
          handler:
        }
      end

      # Returns an array of MCP::Tool instances for server initialization
      def mcp_tools
        tools.map { |t| build_mcp_tool(t) }
      end

      # Register tools on an MCP::Server instance (used in tests)
      def register(server)
        tools.each do |t|
          mcp_tool = build_mcp_tool(t)
          server.tools[mcp_tool.name_value] = mcp_tool
        end
      end

      # Response helpers — available to handler blocks via lexical scope (self == subclass)
      def text_response(data)
        ::MCP::Tool::Response.new([{ type: "text", text: JSON.pretty_generate(data) }])
      end

      def message_response(msg)
        ::MCP::Tool::Response.new([{ type: "text", text: msg }])
      end

      def error_response(msg)
        ::MCP::Tool::Response.new([{ type: "text", text: msg }], error: true)
      end

      private

      def normalize_schema(schema)
        result = {
          type: "object",
          properties: schema[:properties] || {}
        }
        required = schema[:required]
        result[:required] = required if required && !required.empty?
        result
      end

      def build_mcp_tool(t)
        handler = t[:handler]
        ::MCP::Tool.define(
          name: t[:name],
          description: t[:description],
          input_schema: t[:input_schema]
        ) do |**kwargs|
          server_context = kwargs.delete(:server_context) || {}
          arguments = kwargs.transform_keys(&:to_s)
          handler.call(arguments, server_context)
        end
      end
    end
  end
end
