# frozen_string_literal: true

require "zeitwerk"
require "mcp"
require "sequel"

module DoorLoopApp
  class << self
    def loader
      @loader ||= begin
        loader = Zeitwerk::Loader.for_gem
        loader.inflector.inflect("doorloop_app" => "DoorLoopApp", "cli" => "CLI", "llm" => "LLM")
        loader.setup
        loader
      end
    end

    def eager_load!
      loader.eager_load
    end

    def configuration
      @configuration ||= Configuration.new
    end
    alias_method :config, :configuration

    def configure
      yield configuration
    end

    def session
      @session ||= Browser::Session.new
    end

    def store
      @store ||= Store.new(db_path: configuration.db_path)
    end

    def executor
      @executor ||= Data::Executor.new(
        session: session,
        api_client: Api::Client.new(session: session),
        store: store
      )
    end

    def service
      @service ||= Service.new(executor: executor, store: store)
    end

    def root
      File.expand_path("..", __dir__)
    end
  end

  loader
end
