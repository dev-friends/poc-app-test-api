class TestRunsController < ApplicationController
  def index
    runs = TestRun.order(created_at: :desc).limit(50)
    render json: runs.map { |r| TestRunSerializer.new(r).as_json }
  end

  def show
    test_run = TestRun.find(params[:id])
    render json: TestRunSerializer.new(test_run).as_json(include_results: true)
  end

  def create
    test_run = TestRun.new(status: :pending, target_url: params[:target_url].presence || ENV["SAMPLE_EXTERNAL_APP_URL"])
    test_run.save!
    RunExternalTestSuiteJob.perform_later(test_run.id)
    render json: TestRunSerializer.new(test_run).as_json, status: :created
  rescue ActiveRecord::RecordNotUnique
    current = TestRun.active.order(created_at: :desc).first
    render json: {
      error: "A test run is already in progress",
      current_run: current && TestRunSerializer.new(current).as_json
    }, status: :conflict
  end

  def status
    running = TestRun.active.order(created_at: :desc).first
    last = TestRun.finished.order(finished_at: :desc).first

    render json: {
      running: running.present?,
      current_run: running && TestRunSerializer.new(running).as_json,
      last_run: last && TestRunSerializer.new(last).as_json,
      ever_run: TestRun.exists?
    }
  end

  def results
    test_run = TestRun.find(params[:id])
    render json: test_run.test_case_results.map { |c| TestCaseResultSerializer.new(c).as_json }
  end
end
