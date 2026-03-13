# frozen_string_literal: true

module DoorloopMcp
  module MCP
    module Tools
      class LoginTool < Tool
        tool "doorloop_login",
          description: "Login to DoorLoop. If 2FA is required and AgentMail is not configured, returns a two_factor_required status — then call doorloop_submit_2fa with the code." do |_args, server_context|
          session = server_context[:session]
          result = session.authenticate!

          if result[:status] == :two_factor_required
            next message_response(
              "Two-factor authentication required. A verification code was sent to your email. " \
              "Use the doorloop_submit_2fa tool with the 6-digit code to complete login."
            )
          end

          # Login succeeded — extract tokens for API layer
          token_store = server_context[:token_store]
          if token_store
            token_data = session.extract_auth_tokens
            token_store.update(token: token_data[:token], token_type: :bearer) if token_data
          end

          message_response("Successfully logged in to DoorLoop as #{DoorloopMcp.configuration.email}.")
        rescue => e
          error_response("Login failed: #{e.message}")
        end
      end
    end
  end
end
