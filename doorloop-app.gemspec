# frozen_string_literal: true

require_relative "lib/doorloop_app/version"

Gem::Specification.new do |spec|
  spec.name = "doorloop-app"
  spec.version = DoorLoopApp::VERSION
  spec.authors = ["Ajaya Agrawalla"]
  spec.summary = "MCP server for DoorLoop property management"
  spec.description = "A Ruby MCP server that lets AI assistants interact with DoorLoop via Playwright browser automation"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.files = Dir["lib/**/*", "bin/*", "LICENSE", "README.md"]
  spec.bindir = "bin"
  spec.executables = ["doorloop"]

  spec.add_dependency "agentmail", "~> 0.1"
  spec.add_dependency "ruby-anthropic", "~> 0.4"
  spec.add_dependency "dotenv", "~> 3.0"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "playwright-ruby-client", "~> 1.49"
  spec.add_dependency "instructor-rb"
  spec.add_dependency "mcp", ">= 0.8.0"
  spec.add_dependency "rack", "~> 3.1"
  spec.add_dependency "rackup", "~> 2.2"
  spec.add_dependency "ruby_llm", "~> 1.0"
  spec.add_dependency "sequel", "~> 5.0"
  spec.add_dependency "sqlite3", "~> 2.0"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "webrick", "~> 1.9"
  spec.add_dependency "zeitwerk", "~> 2.7"

  spec.add_development_dependency "awesome_print"
  spec.add_development_dependency "irb"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-reporters", "~> 1.7"
  spec.add_development_dependency "mocha", "~> 2.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake", "~> 13.0"
end
