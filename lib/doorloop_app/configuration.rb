# frozen_string_literal: true

module DoorLoopApp
  class Configuration
    attr_accessor :email, :password, :url,
                  :headless, :profile_dir, :agent_browser_path, :browser_executable, :browser_args,
                  :agentmail_api_key, :agentmail_inbox_id,
                  :anthropic_api_key, :vision_model, :llm_model, :allow_paid_ai,
                  :api_registry_path,
                  :db_path,
                  :confirmation_email_to

    def initialize
      @email = ENV.fetch("DOORLOOP_EMAIL", nil)
      @password = ENV.fetch("DOORLOOP_PASSWORD", nil)
      @url = ENV.fetch("DOORLOOP_URL", "https://bansals.app.doorloop.com")
      @headless = ENV.fetch("DOORLOOP_HEADLESS", "true") != "false"
      @profile_dir = ENV.fetch("DOORLOOP_PROFILE_DIR", File.expand_path("~/.doorloop-mcp/chrome-profile"))
      local_driver = File.join(DoorLoopApp.root, "node_modules", ".bin", "agent-browser")
      @agent_browser_path = ENV.fetch("DOORLOOP_AGENT_BROWSER_PATH", File.executable?(local_driver) ? local_driver : "agent-browser")
      @browser_executable = ENV["DOORLOOP_BROWSER_EXECUTABLE"]
      @browser_args = ENV.fetch("DOORLOOP_BROWSER_ARGS", "")
      @agentmail_api_key = ENV.fetch("AGENTMAIL_API_KEY", nil)
      @agentmail_inbox_id = ENV.fetch("AGENTMAIL_INBOX_ID", nil)
      @anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
      @allow_paid_ai = ENV.fetch("DOORLOOP_ALLOW_PAID_AI", "false") == "true"
      @vision_model = ENV.fetch("DOORLOOP_VISION_MODEL", "claude-sonnet-4-20250514")
      @llm_model    = ENV.fetch("DOORLOOP_LLM_MODEL", "claude-haiku-4-5-20251001")
      @api_registry_path = ENV.fetch("DOORLOOP_API_REGISTRY", File.expand_path("~/.doorloop-mcp/api_registry.json"))
      @db_path = ENV.fetch("DOORLOOP_DB_PATH", File.join(File.expand_path("~/.doorloop-mcp"), "doorloop.sqlite3"))

      # Payment confirmation email recipient
      @confirmation_email_to = ENV.fetch("DOORLOOP_CONFIRMATION_EMAIL_TO", nil)
    end

    def validate!
      raise "DOORLOOP_EMAIL is required" unless email
      raise "DOORLOOP_PASSWORD is required" unless password
    end

    def agentmail_configured?
      agentmail_api_key && agentmail_inbox_id
    end

    def vision_configured?
        allow_paid_ai && !anthropic_api_key.to_s.empty?
    end

    def email_notifications_configured?
      agentmail_configured? && !!confirmation_email_to
    end
  end
end
