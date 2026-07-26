require "capybara"
require "capybara/cuprite"

# Default host for specs that don't declare their own `app_host:` tag (see
# support/app_host.rb) — there's no request-level override anymore, every
# spec is expected to pin its own target.
Capybara.app_host = "https://the-internet.herokuapp.com"
Capybara.run_server = false
Capybara.default_driver = :cuprite
Capybara.javascript_driver = :cuprite
Capybara.default_max_wait_time = ENV.fetch("CAPYBARA_MAX_WAIT_TIME", 10).to_i

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [1400, 1000],
    headless: ENV.fetch("HEADLESS", "true") == "true",
    js_errors: true,
    process_timeout: 15,
    timeout: 15,
    browser_path: ENV["CHROME_BIN"],
    browser_options: ENV["CHROME_BIN"] ? { "no-sandbox" => nil, "disable-gpu" => nil, "disable-dev-shm-usage" => nil } : {}
  )
end
