require "rails_helper"

RSpec.describe RunExternalTestSuiteJob do
  let(:test_run) { TestRun.create!(status: :pending, target_url: "https://example.com") }

  def stub_rspec_output(json_path, payload)
    allow(Open3).to receive(:capture3) do |*_args, **_kwargs|
      FileUtils.mkdir_p(json_path.dirname)
      File.write(json_path, payload.to_json)
      ["", "", instance_double(Process::Status, success?: payload.dig("summary", "failure_count").to_i.zero?, exitstatus: 0)]
    end
  end

  it "marks the run completed and imports passing results" do
    json_path = Rails.root.join("tmp", "test_runs", "run_#{test_run.id}.json")
    stub_rspec_output(json_path, {
      "examples" => [
        { "full_description" => "does a thing", "description" => "does a thing", "status" => "passed", "run_time" => 1.2 }
      ],
      "summary" => { "example_count" => 1, "failure_count" => 0, "pending_count" => 0, "errors_outside_of_examples_count" => 0 }
    })

    described_class.perform_now(test_run.id)

    test_run.reload
    expect(test_run.status).to eq("completed")
    expect(test_run.passed_count).to eq(1)
    expect(test_run.test_case_results.sole.status).to eq("passed")
  end

  it "marks the run failed and captures the error message when an example fails" do
    json_path = Rails.root.join("tmp", "test_runs", "run_#{test_run.id}.json")
    stub_rspec_output(json_path, {
      "examples" => [
        {
          "full_description" => "breaks",
          "description" => "breaks",
          "status" => "failed",
          "run_time" => 0.5,
          "exception" => { "message" => "expected foo, got bar", "backtrace" => ["spec.rb:1"] }
        }
      ],
      "summary" => { "example_count" => 1, "failure_count" => 1, "pending_count" => 0, "errors_outside_of_examples_count" => 0 }
    })

    described_class.perform_now(test_run.id)

    test_run.reload
    expect(test_run.status).to eq("failed")
    expect(test_run.test_case_results.sole.error_message).to eq("expected foo, got bar")
  end

  it "marks the run failed when rspec produces no output" do
    allow(Open3).to receive(:capture3).and_return(["", "boom", instance_double(Process::Status, success?: false, exitstatus: 1)])

    described_class.perform_now(test_run.id)

    test_run.reload
    expect(test_run.status).to eq("failed")
    expect(test_run.error_message).to include("boom")
  end
end
