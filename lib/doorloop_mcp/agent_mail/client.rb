# frozen_string_literal: true

require "agentmail"
require "cgi"

module DoorloopMcp
  module AgentMail
    class Client
      DEFAULT_POLL_INTERVAL = 3 # seconds
      DEFAULT_TIMEOUT = 120    # seconds

      attr_reader :inbox_id

      def initialize(api_key: nil, inbox_id: nil)
        config = DoorloopMcp.configuration
        @api_key = api_key || config.agentmail_api_key
        @inbox_id = inbox_id || config.agentmail_inbox_id

        raise "AGENTMAIL_API_KEY is required" unless @api_key
        raise "AGENTMAIL_INBOX_ID is required" unless @inbox_id

        @client = ::Agentmail::Client.new(api_key: @api_key)
      end

      # Returns the inbox details as a Hash
      def inbox
        response = @client.inboxes.retrieve(@inbox_id)
        response.respond_to?(:body) ? response.body : response
      end

      # Lists messages in the inbox
      # Options: limit, after (ISO8601 timestamp), before, ascending
      # Returns a Hash with "messages" array
      def list_messages(**opts)
        params = { limit: opts.fetch(:limit, 10) }
        params[:after] = opts[:after] if opts[:after]
        params[:before] = opts[:before] if opts[:before]
        params[:ascending] = opts[:ascending] if opts.key?(:ascending)

        response = @client.request(:get, "/v0/inboxes/#{@inbox_id}/messages", params: params)
        response.body
      end

      # Retrieves a single message by ID (includes full body text/html)
      # Returns a Hash with message fields
      def get_message(message_id)
        encoded_id = CGI.escape(message_id)
        response = @client.request(:get, "/v0/inboxes/#{@inbox_id}/messages/#{encoded_id}")
        response.body
      end

      VERIFICATION_CODE_PATTERN = /verification code is:\s*(\d{6})/i

      # Extracts a 6-digit verification code from an email message hash.
      # Checks text body, then html body, then extracted_text.
      # Returns the code string or nil.
      def self.extract_verification_code(message)
        ["text", "html", "extracted_text"].each do |field|
          body = message[field].to_s
          match = body.match(VERIFICATION_CODE_PATTERN)
          return match[1] if match
        end
        nil
      end

      # Returns the inbox email address (e.g. "abc123@agentmail.to")
      def inbox_email
        @inbox_email ||= begin
          data = inbox
          data["email"] || data[:email]
        end
      end

      # Sends an email from this inbox.
      # to:      recipient address (required)
      # subject: email subject (required)
      # text:    plain-text body
      def send_message(to:, subject:, text: "")
        response = @client.request(
          :post,
          "/v0/inboxes/#{@inbox_id}/messages",
          body: { to: to, subject: subject, text: text }
        )
        response.body
      end

      # Waits for a DoorLoop 2FA email and returns the 6-digit code.
      # Raises if no matching email arrives or code can't be extracted.
      # Note: emails may be forwarded, so we only filter by subject (not from).
      def wait_for_verification_code(timeout: DEFAULT_TIMEOUT, poll_interval: DEFAULT_POLL_INTERVAL)
        # Go back 30s to catch emails that arrived just before the trigger
        timestamp_before = (Time.now.utc - 30).iso8601
        message = wait_for_message(
          subject_contains: "verification",
          after: timestamp_before,
          timeout: timeout,
          poll_interval: poll_interval
        )

        code = self.class.extract_verification_code(message)
        raise "Could not extract verification code from email: #{message["subject"]}" unless code

        $stderr.puts "Extracted 2FA code: #{code}"
        code
      end

      # Polls for a new message matching the given criteria.
      # Returns the full message hash or raises on timeout.
      #
      # Options:
      #   from:             — filter by sender (substring match)
      #   subject_contains: — filter by subject (substring match)
      #   after:            — only consider messages after this ISO8601 timestamp
      #   timeout:          — max seconds to wait (default 120)
      #   poll_interval:    — seconds between polls (default 3)
      def wait_for_message(from: nil, subject_contains: nil, after: nil, timeout: DEFAULT_TIMEOUT, poll_interval: DEFAULT_POLL_INTERVAL)
        after ||= Time.now.utc.iso8601
        deadline = Time.now + timeout

        $stderr.puts "Waiting for email in AgentMail inbox #{@inbox_id}..."
        $stderr.puts "  from: #{from}" if from
        $stderr.puts "  subject contains: #{subject_contains}" if subject_contains

        attempt = 0
        loop do
          raise "Timed out waiting for email after #{timeout}s" if Time.now > deadline

          attempt += 1
          response = list_messages(after: after, ascending: true, limit: 25)
          messages = response["messages"] || []
          $stderr.puts "  Poll ##{attempt}: #{messages.length} messages found (after: #{after})"

          match = messages.find do |msg|
            next if from && !msg["from"].to_s.downcase.include?(from.downcase)
            next if subject_contains && !msg["subject"].to_s.downcase.include?(subject_contains.downcase)
            true
          end

          if match
            full_message = get_message(match["message_id"])
            $stderr.puts "Found matching email: #{full_message["subject"]}"
            return full_message
          end

          sleep poll_interval
        end
      end
    end
  end
end
