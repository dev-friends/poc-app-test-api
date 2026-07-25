require "capybara"
require "capybara/cuprite"

# Defaults to a stable public demo site so the app is demonstrable out of the
# box, before SAMPLE_EXTERNAL_APP_URL is pointed at the real target app.
Capybara.app_host = ENV.fetch("SAMPLE_EXTERNAL_APP_URL", "https://the-internet.herokuapp.com")
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
