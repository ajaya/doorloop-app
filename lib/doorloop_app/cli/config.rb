# frozen_string_literal: true

module DoorLoopApp
  module CLI
    class Config < Base
      LABEL_WIDTH = 14
      VALUE_WIDTH = 52
      ANSI_RE     = /\e\[[0-9;]*m/

      desc "show", "Show current configuration and status of all components"
      def show
        print_config(DoorLoopApp.configuration)
      end

      default_task :show

      # Called by CLI::Main#server so config is printed on every server start.
      def self.print!(config = DoorLoopApp.configuration)
        new.print_config(config)
      end

      no_commands do
        def print_config(config)
          io = $stderr

          io.puts ""
          io.puts "DoorLoop MCP v#{DoorLoopApp::VERSION} — Configuration"
          io.puts "═" * 54

          # ── DoorLoop ──────────────────────────────────────────────
          section(io, "DoorLoop")
          row(io, "URL",      config.url,      env_source("DOORLOOP_URL"))
          row(io, "Email",    config.email,    env_source("DOORLOOP_EMAIL"),    required: true)
          row(io, "Password", config.password, env_source("DOORLOOP_PASSWORD"), secret: true, required: true)

          # ── Chrome ────────────────────────────────────────────────
          section(io, "Chrome")
          row(io, "Headless",    config.headless.to_s, env_source("DOORLOOP_HEADLESS"))
          row(io, "Profile Dir", config.profile_dir,   env_source("DOORLOOP_PROFILE_DIR"),
              annotation: path_status(config.profile_dir))

          # ── AgentMail ─────────────────────────────────────────────
          section(io, "AgentMail (2FA & notifications)",
                  status: config.agentmail_configured? ? :ok : :off,
                  status_label: config.agentmail_configured? ? "configured" : "not configured")
          row(io, "API Key",  config.agentmail_api_key,  env_source("AGENTMAIL_API_KEY"),  secret: true)
          row(io, "Inbox ID", config.agentmail_inbox_id, env_source("AGENTMAIL_INBOX_ID"), secret: true)

          # ── Claude AI ─────────────────────────────────────────────
          section(io, "Claude AI (LLM + vision)",
                  status: config.vision_configured? ? :ok : :off,
                  status_label: config.vision_configured? ? "configured" : "not configured — LLM/vision disabled")
          row(io, "Anthropic Key", config.anthropic_api_key, env_source("ANTHROPIC_API_KEY"), secret: true)
          row(io, "LLM Model",     config.llm_model,         env_source("DOORLOOP_LLM_MODEL"))
          row(io, "Vision Model",  config.vision_model,      env_source("DOORLOOP_VISION_MODEL"))

          # ── Database ──────────────────────────────────────────────
          section(io, "Database")
          row(io, "SQLite Path", config.db_path, env_source("DOORLOOP_DB_PATH"),
              annotation: path_status(config.db_path))

          # ── API Registry ──────────────────────────────────────────
          section(io, "API Registry")
          row(io, "Path", config.api_registry_path, env_source("DOORLOOP_API_REGISTRY"),
              annotation: path_status(config.api_registry_path))

          # ── Email Notifications ───────────────────────────────────
          section(io, "Email Notifications",
                  status: config.email_notifications_configured? ? :ok : :off,
                  status_label: config.email_notifications_configured? ? "configured" : "not configured")
          row(io, "To", config.confirmation_email_to, env_source("DOORLOOP_CONFIRMATION_EMAIL_TO"))

          io.puts ""
        end
      end

      private

      def section(io, title, status: nil, status_label: nil)
        io.puts ""
        badge = case status
                when :ok  then " \e[32m✓ #{status_label}\e[0m"
                when :off then " \e[33m○ #{status_label}\e[0m"
                else ""
                end
        io.puts "  \e[1m#{title}\e[0m#{badge}"
      end

      def row(io, label, value, source, secret: false, required: false, annotation: nil)
        display_value  = format_value(value, secret: secret, required: required)
        source_tag     = source == :env ? "\e[36menv\e[0m    " : "\e[90mdefault\e[0m"
        annotation_str = annotation ? "  #{annotation}" : ""

        io.puts "    #{label.ljust(LABEL_WIDTH)}  #{ansi_ljust(display_value, VALUE_WIDTH)}  #{source_tag}#{annotation_str}"
      end

      def format_value(value, secret: false, required: false)
        if value.nil? || (value.respond_to?(:empty?) && value.empty?)
          return required ? "\e[31m(not set — required)\e[0m" : "\e[90m(not set)\e[0m"
        end
        return mask(value) if secret

        value.to_s
      end

      def mask(value)
        str = value.to_s
        return "\e[90m(not set)\e[0m" if str.empty?

        visible = [str.length / 3, 6].min
        "\e[33m#{str[0, visible]}#{"●" * [str.length - visible, 8].min}\e[0m"
      end

      def ansi_ljust(str, width)
        visible = str.gsub(ANSI_RE, "").length
        str + " " * [width - visible, 0].max
      end

      def env_source(var)
        ENV.key?(var) ? :env : :default
      end

      def path_status(path)
        return nil unless path

        expanded = File.expand_path(path)
        File.exist?(expanded) ? "\e[32m✓ exists\e[0m" : "\e[90m○ not found\e[0m"
      end
    end
  end
end
