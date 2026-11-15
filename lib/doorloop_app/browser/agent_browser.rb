# frozen_string_literal: true

require "open3"
require "json"
require "digest"
require "fileutils"

module DoorLoopApp
  module Browser
    # Only local, non-LLM commands are used. Credentials and scripts travel over
    # stdin, never shell interpolation or process arguments.
    class AgentBrowser
      attr_reader :session_name

      def initialize(config: DoorLoopApp.configuration)
        @config = config
        @profile = File.expand_path(config.profile_dir)
        @session_name = "doorloop-#{Digest::SHA256.hexdigest(@profile)[0, 16]}"
        @mutex = Mutex.new
      end

      def command(*args, timeout: 30_000)
        @mutex.synchronize do
          FileUtils.mkdir_p(@profile, mode: 0o700)
          config_path = File.join(@profile, "doorloop-agent-browser.json")
          File.write(config_path, "{}\n", mode: "w", perm: 0o600)
          # Do not inherit a paid provider, remote CDP endpoint, or unrelated
          # agent's session from the host environment.
          env = ENV.keys.grep(/\AAGENT_BROWSER_/).to_h { |key| [key, nil] }
          env["AGENT_BROWSER_NO_VERSION_CHECK"] = "1"
          env["AGENT_BROWSER_DEFAULT_TIMEOUT"] = timeout.to_s
          argv = [@config.agent_browser_path, "--config", config_path, "--json", "--session", session_name,
                  "--profile", @profile, "--provider", "", "--no-auto-connect",
                  "--engine", "chrome"]
          argv += ["--headed"] unless @config.headless
          argv += ["--executable-path", @config.browser_executable] if @config.browser_executable
          argv += ["--args", @config.browser_args] unless @config.browser_args.empty?
          argv += ["batch", "--bail", "--omit-command"]
          stdout, _stderr, status = Open3.capture3(env, *argv, stdin_data: JSON.generate([args]))
          row = JSON.parse(stdout).first
          unless status.success? && row && row["success"]
            raise Error, "agent-browser #{args.first} failed (arguments and response withheld)"
          end
          row.fetch("result", {})
        end
      rescue JSON::ParserError, TypeError
        raise Error, "agent-browser returned an invalid response"
      rescue Errno::ENOENT
        raise Error, "agent-browser is not installed; run npm ci or set DOORLOOP_AGENT_BROWSER_PATH"
      end

      def cookies
        command("cookies").fetch("cookies")
      end

      def close
        command("close")
      end
    end
  end
end
