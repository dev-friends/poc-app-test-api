require "rspec/core/formatters/json_formatter"

# Extends RSpec's built-in `--format json` to also include each example's
# `app_host:` tag, so RunExternalTestSuiteJob can persist it per
# TestCaseResult — there's no more run-wide target_url to fall back to.
class JsonWithAppHostFormatter < RSpec::Core::Formatters::JsonFormatter
  RSpec::Core::Formatters.register self, :message, :dump_summary, :dump_profile, :stop, :seed, :close

  private

  def format_example(example)
    super.merge(app_host: example.metadata[:app_host])
  end
end
