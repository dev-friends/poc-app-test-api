require "open3"

class RunExternalTestSuiteJob < ApplicationJob
  queue_as :test_runs

  def perform(test_run_id)
    test_run = TestRun.find(test_run_id)
    test_run.update!(status: :running, started_at: Time.current)

    suite_dir = Rails.root.join("test_suites", "external_app")
    json_path = Rails.root.join("tmp", "test_runs", "run_#{test_run.id}.json")
    FileUtils.mkdir_p(json_path.dirname)

    env = { "HEADLESS" => "true" }
    env["TARGET_URL"] = test_run.target_url if test_run.target_url.present?

    _stdout, stderr, process_status = Open3.capture3(
      env,
      "bundle", "exec", "rspec",
      "-O", suite_dir.join(".rspec").to_s,
      "--require", suite_dir.join("spec_helper").to_s,
      "--format", "json", "--out", json_path.to_s,
      suite_dir.join("specs").to_s,
      chdir: Rails.root.to_s
    )

    if File.exist?(json_path)
      import_results!(test_run, JSON.parse(File.read(json_path)), process_status)
    else
      test_run.update!(
        status: :failed,
        finished_at: Time.current,
        error_message: "RSpec did not produce output. exit=#{process_status.exitstatus} stderr=#{stderr.to_s.truncate(5000)}"
      )
    end
  rescue => e
    test_run.update!(status: :failed, finished_at: Time.current, error_message: "#{e.class}: #{e.message}")
  ensure
    FileUtils.rm_f(json_path) if defined?(json_path)
  end

  private

  def import_results!(test_run, json, process_status)
    summary = json["summary"] || {}

    ActiveRecord::Base.transaction do
      json.fetch("examples", []).each do |ex|
        test_run.test_case_results.create!(
          full_description: ex["full_description"],
          description: ex["description"],
          file_path: ex["file_path"],
          line_number: ex["line_number"],
          status: %w[passed failed pending].include?(ex["status"]) ? ex["status"] : "failed",
          run_time: ex["run_time"],
          error_message: ex.dig("exception", "message"),
          error_backtrace: Array(ex.dig("exception", "backtrace")).join("\n")
        )
      end

      errored = summary["failure_count"].to_i > 0 ||
                summary["errors_outside_of_examples_count"].to_i > 0 ||
                !process_status.success?

      test_run.update!(
        status: errored ? :failed : :completed,
        finished_at: Time.current,
        total_count: summary["example_count"],
        failed_count: summary["failure_count"],
        pending_count: summary["pending_count"],
        passed_count: summary["example_count"].to_i - summary["failure_count"].to_i - summary["pending_count"].to_i
      )
    end
  end
end
