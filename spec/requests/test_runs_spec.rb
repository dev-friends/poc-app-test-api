require "rails_helper"

RSpec.describe "TestRuns", type: :request do
  describe "GET /test_runs/status" do
    it "reports that no run has ever happened" do
      get "/test_runs/status", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "running" => false, "current_run" => nil, "last_run" => nil, "ever_run" => false
      )
    end

    it "reports the currently running run" do
      running = TestRun.create!(status: :running, started_at: Time.current)

      get "/test_runs/status", headers: auth_headers

      body = response.parsed_body
      expect(body["running"]).to be true
      expect(body["current_run"]["id"]).to eq(running.id)
    end
  end

  describe "POST /test_runs" do
    it "creates a pending run and enqueues the job" do
      expect {
        post "/test_runs", params: { target_url: "https://example.com" }, headers: auth_headers
      }.to have_enqueued_job(RunExternalTestSuiteJob)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["status"]).to eq("pending")
      expect(TestRun.find(body["id"]).target_url).to eq("https://example.com")
    end

    it "returns 409 when a run is already active" do
      TestRun.create!(status: :running, started_at: Time.current)

      post "/test_runs", headers: auth_headers

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["error"]).to be_present
    end
  end

  describe "GET /test_runs/:id/results" do
    it "lists the test case results for a run" do
      run = TestRun.create!(status: :failed, started_at: 1.minute.ago, finished_at: Time.current)
      run.test_case_results.create!(full_description: "passes", status: :passed, run_time: 1.0)
      run.test_case_results.create!(full_description: "fails", status: :failed, run_time: 1.0, error_message: "boom")

      get "/test_runs/#{run.id}/results", headers: auth_headers

      statuses = response.parsed_body.map { |r| r["status"] }
      expect(statuses).to contain_exactly("passed", "failed")
    end
  end

  describe "authentication" do
    it "rejects requests without a token" do
      get "/test_runs/status"

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects requests with the wrong token" do
      get "/test_runs/status", headers: { "Authorization" => "Bearer wrong-token" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
