# frozen_string_literal: true

module DoorloopMcp
  module MCP
    module Tools
      class Submit2faTool < Tool
        tool "doorloop_submit_2fa",
          description: "Submit the 2FA verification code to complete DoorLoop login. Call this after doorloop_login returns a two_factor_required status.",
          input_schema: {
            properties: {
              code: {
                type: "string",
                description: "The 6-digit verification code from the email"
              }
            },
            required: ["code"]
          } do |args, server_context|
          session = server_context[:session]
          result = session.submit_2fa_code(args["code"])

          if result[:status] == :logged_in
            token_store = server_context[:token_store]
            if token_store
              token_data = session.extract_auth_tokens
              token_store.update(token: token_data[:token], token_type: :bearer) if token_data
            end

            message_response("Successfully logged in to DoorLoop after 2FA verification.")
          else
            error_response("2FA submission did not complete login. Status: #{result[:status]}")
          end
        rescue => e
          error_response("2FA submission failed: #{e.message}")
        end
      end
    end
  end
end
