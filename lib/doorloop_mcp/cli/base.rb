# frozen_string_literal: true

require "thor"
require "json"

module DoorloopMcp
  module CLI
    class Base < Thor
      def self.exit_on_failure?
        true
      end

      private

      # Progress/error messages → stderr (stays clean for MCP JSON-RPC when running as server)
      def say(message = "", *)
        $stderr.puts message
      end

      def say_error(message)
        $stderr.puts "ERROR: #{message}"
      end

      # Data output → stdout so it can be piped/redirected
      def print_json(data)
        $stdout.puts JSON.pretty_generate(data)
      end

      # Simple columnar table to stdout
      def print_table_data(rows, headers)
        return $stdout.puts "(none)" if rows.empty?

        widths = headers.each_with_index.map do |h, i|
          [h.length, rows.map { |r| r[i].to_s.length }.max.to_i].max
        end

        $stdout.puts headers.each_with_index.map { |h, i| h.ljust(widths[i]) }.join("  ")
        $stdout.puts widths.map { |w| "-" * w }.join("  ")
        rows.each { |row| $stdout.puts row.each_with_index.map { |c, i| c.to_s.ljust(widths[i]) }.join("  ") }
        $stdout.puts "\n#{rows.size} record(s)"
      end

      # Authenticate and run a block that needs a live browser (e.g. payment, transactions).
      # Session is stopped on exit. Use DoorloopMcp.service inside the block.
      def run_with_session
        DoorloopMcp.session.start
        DoorloopMcp.session.ensure_authenticated!
        yield
      rescue => e
        say_error e.message
        exit 1
      ensure
        DoorloopMcp.session.stop rescue nil
      end

      def empty_db_error(command)
        say_error "No data in local DB. Run `#{command} --refresh` to fetch from DoorLoop."
        exit 1
      end
    end
  end
end
