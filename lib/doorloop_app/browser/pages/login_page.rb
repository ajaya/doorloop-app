# frozen_string_literal: true

module DoorLoopApp
  module Browser
    module Pages
      class LoginPage < PageObject
        LOGIN_URL = "https://app.doorloop.com/auth/login"

        def login(email, password)
          log "Navigating to #{LOGIN_URL}..."
          page.goto(LOGIN_URL, waitUntil: "domcontentloaded")
          sleep 3

          if already_logged_in?
            log "Already logged in. Skipping login."
            return { status: :logged_in }
          end

          log "Filling email..."
          page.fill("#email", email)
          sleep 0.5

          log "Filling password..."
          page.fill("#password", password)
          sleep 0.5

          log "Submitting login form..."
          page.click('[data-cy="signIn"]')
          sleep 5

          log "Post-login URL: #{session.current_url}"

          if two_factor_page?
            log "Two-Factor Authentication required."
            check_dont_ask_again

            if DoorLoopApp.configuration.agentmail_configured?
              begin
                code = fetch_2fa_via_agentmail
                return submit_2fa_code(code)
              rescue => e
                log "AgentMail 2FA failed: #{e.message}. Manual code entry required."
              end
            end

            return { status: :two_factor_required }
          end

          wait_for_dashboard
          log "Login complete. URL: #{session.current_url}"
          { status: :logged_in }
        end

        def submit_2fa_code(code)
          raise "No 2FA code provided" if code.nil? || code.empty?

          log "Entering 2FA code: #{code}"
          fill_otp_inputs(code)

          sleep 1
          log "Submitting 2FA..."
          submit_2fa_form
          sleep 5

          log "Post-2FA URL: #{session.current_url}"
          wait_for_dashboard
          log "Login complete after 2FA. URL: #{session.current_url}"
          { status: :logged_in }
        end

        private

        def log(msg)
          $stderr.puts "[Login] #{msg}"
        end

        def already_logged_in?
          url = session.current_url
          log "Current URL: #{url}"
          !url.include?("/auth")
        end

        def two_factor_page?
          url = session.current_url
          text = session.text_content
          url.include?("/auth") && text.match?(/two.?factor|verification code|2fa/i)
        end

        def check_dont_ask_again
          loc = page.locator("[role='checkbox']")
          if loc.count > 0
            log "Checking 'Don't ask me again'..."
            loc.first.click(timeout: 3000)
          else
            log "No 'Don't ask again' checkbox found."
          end
        rescue => e
          log "Could not check 'Don't ask again': #{e.message}"
        end

        def fetch_2fa_via_agentmail
          log "Fetching 2FA code via AgentMail (30s timeout)..."
          client = DoorLoopApp::AgentMail::Client.new
          client.wait_for_verification_code(timeout: 30)
        end

        def submit_2fa_form
          sign_in_loc = page.locator('button:has-text("Sign in")')
          if sign_in_loc.count > 0
            log "Clicking Sign in button..."
            sign_in_loc.first.click(timeout: 5000)
          else
            log "No Sign in button found, pressing Enter..."
            page.keyboard.press("Enter")
          end
        end

        def fill_otp_inputs(code)
          # DoorLoop uses a single input (maxlength=6) for the OTP code.
          # The type attribute is set via JS, so use page.evaluate to find and fill it
          # rather than relying on Playwright's attribute-based locator.
          filled = page.evaluate(<<~JS)
            var input = document.querySelector('input:not([type="hidden"])');
            if (input) { input.focus(); input.value = ''; }
            !!input;
          JS

          if filled
            log "Typing OTP code into input..."
            code.chars.each do |digit|
              page.keyboard.press(digit)
              sleep 0.05
            end
          else
            log "No OTP input found, typing via keyboard..."
            code.chars.each do |digit|
              page.keyboard.press(digit)
              sleep 0.1
            end
          end
        end

        def wait_for_dashboard
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          loop do
            sleep 2
            url = session.current_url
            log "Waiting for dashboard... URL: #{url}"
            break unless url.include?("/auth/login") || url.include?("/signin") || url.include?("/auth/")
            elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
            raise "Login failed: still on login page after #{elapsed.round}s" if elapsed > 60
          end
        end
      end
    end
  end
end
