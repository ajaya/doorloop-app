# frozen_string_literal: true

module DoorLoopApp
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

        message_response("Successfully logged in to DoorLoop as #{DoorLoopApp.configuration.email}.")
      rescue => e
        error_response("Login failed: #{e.message}")
      end
    end
  end
end
