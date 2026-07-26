require_relative "support/capybara_setup"
require_relative "support/app_host"
require_relative "support/json_with_app_host_formatter"
require "capybara/rspec"

RSpec.configure do |config|
  # These specs don't live under spec/features, so Capybara's automatic
  # `type: :feature` inference never kicks in — include the DSL explicitly.
  config.include Capybara::DSL
  config.include Capybara::RSpecMatchers

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.after { Capybara.reset_sessions! }
end
