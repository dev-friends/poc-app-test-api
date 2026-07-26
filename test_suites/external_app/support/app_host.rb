# Lets an individual spec/describe block target a fixed host different from
# the suite-wide Capybara.app_host (set once in capybara_setup.rb from the
# TARGET_URL env var / target_url). Usage:
#
#   RSpec.describe "Other site", app_host: "https://other-site.example.com" do
#     it { visit "/path" } # resolves against the tagged host, not the suite default
#   end
#
# Restored after each example (via `ensure`) because config.order = :random
# would otherwise let the override leak into unrelated specs.
RSpec.configure do |config|
  config.around(:each) do |example|
    host = example.metadata[:app_host]
    next example.run unless host

    original_host = Capybara.app_host
    Capybara.app_host = host
    begin
      example.run
    ensure
      Capybara.app_host = original_host
    end
  end
end
