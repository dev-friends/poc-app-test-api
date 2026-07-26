require "rails_helper"

RSpec.describe "OpencodeRuns", type: :request do
  describe "POST /opencode/runs" do
    it "creates a pending run and enqueues the job" do
      expect {
        post "/opencode/runs", params: { prompt: "reply with exactly: pong" }, headers: auth_headers
      }.to have_enqueued_job(RunOpencodePromptJob)

      expect(response).to have_http_status(:accepted)
      body = response.parsed_body
      expect(body["status"]).to eq("pending")
      expect(OpencodeRun.find(body["id"]).prompt).to eq("reply with exactly: pong")
    end

    it "accepts optional agent/model/session_id params" do
      post "/opencode/runs", params: {
        prompt: "hello", agent: "build", model: "opencode/claude-sonnet-5", session_id: "ses_prev"
      }, headers: auth_headers

      run = OpencodeRun.find(response.parsed_body["id"])
      expect(run.agent).to eq("build")
      expect(run.model).to eq("opencode/claude-sonnet-5")
      expect(run.continue_session_id).to eq("ses_prev")
    end
  end

  describe "GET /opencode/runs/:id" do
    it "returns the persisted run" do
      run = OpencodeRun.create!(status: :completed, prompt: "hi", output_text: "hello back", session_id: "ses_1")

      get "/opencode/runs/#{run.id}", headers: auth_headers

      body = response.parsed_body
      expect(body["output_text"]).to eq("hello back")
      expect(body["session_id"]).to eq("ses_1")
    end
  end

  describe "GET /opencode/runs" do
    it "lists runs most recent first" do
      OpencodeRun.create!(status: :completed, prompt: "first")
      OpencodeRun.create!(status: :completed, prompt: "second")

      get "/opencode/runs", headers: auth_headers

      expect(response.parsed_body.map { |r| r["prompt"] }).to eq(%w[second first])
    end
  end
end
