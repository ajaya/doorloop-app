# frozen_string_literal: true

require "json"
require "fileutils"

module DoorLoopApp
  module Api
    class TokenStore
      attr_reader :token, :token_type

      def initialize(session_dir: nil)
        @session_dir = session_dir || File.dirname(DoorLoopApp.configuration.db_path)
        @token = nil
        @token_type = :bearer
        @expires_at = nil
        @mutex = Mutex.new
        load_from_disk
      end

      def valid?
        @token && !@token.empty? && (@expires_at.nil? || Time.now < @expires_at)
      end

      def update(token:, token_type: :bearer, expires_at: nil)
        @mutex.synchronize do
          @token = token
          @token_type = token_type
          @expires_at = expires_at
          save_to_disk
        end
      end

      def invalidate!
        @mutex.synchronize do
          @token = nil
          @expires_at = nil
          save_to_disk
        end
      end

      def auth_headers
        return {} unless valid?

        case @token_type
        when :bearer
          { "Authorization" => "Bearer #{@token}" }
        when :cookie
          { "Cookie" => @token }
        else
          { "Authorization" => "Bearer #{@token}" }
        end
      end

      private

      def token_path
        File.join(@session_dir, "api_token.json")
      end

      def save_to_disk
        FileUtils.mkdir_p(@session_dir)
        tmp = "#{token_path}.tmp"
        File.write(tmp, JSON.pretty_generate({
          token: @token,
          token_type: @token_type.to_s,
          expires_at: @expires_at&.iso8601
        }))
        File.rename(tmp, token_path)
      rescue => e
        $stderr.puts "Warning: Could not save token: #{e.message}"
      end

      def load_from_disk
        return unless File.exist?(token_path)

        data = JSON.parse(File.read(token_path))
        @token = data["token"]
        @token_type = (data["token_type"] || "bearer").to_sym
        @expires_at = data["expires_at"] ? Time.parse(data["expires_at"]) : nil
      rescue => e
        $stderr.puts "Warning: Could not load token: #{e.message}"
      end
    end
  end
end
