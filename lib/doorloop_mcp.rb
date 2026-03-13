# frozen_string_literal: true

require "zeitwerk"
require "mcp"
require "sequel"

# Allow Sequel::Model subclasses to be defined before their tables exist.
# Tables are created in setup!(db) via migrate!, then bound via set_dataset.
Sequel::Model.require_valid_table = false

module DoorloopMcp
  class << self
    def loader
      @loader ||= begin
        loader = Zeitwerk::Loader.for_gem
        loader.inflector.inflect("mcp" => "MCP", "cli" => "CLI", "llm" => "LLM")
        loader.setup
        loader
      end
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
