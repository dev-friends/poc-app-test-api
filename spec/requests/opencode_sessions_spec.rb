require "rails_helper"

RSpec.describe "OpencodeSessions", type: :request do
  describe "GET /opencode/sessions" do
    it "returns the raw session list output" do
      allow(OpencodeCli).to receive(:exec).with("session", "list")
        .and_return(["ses_1  Some title  1:00 PM\n", "", instance_double(Process::Status, success?: true)])

      get "/opencode/sessions", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["output"]).to include("ses_1")
    end
  end

  describe "DELETE /opencode/sessions/:id" do
    it "deletes a session and returns the CLI output" do
      allow(OpencodeCli).to receive(:exec).with("session", "delete", "ses_1")
        .and_return(["Session ses_1 deleted\n", "", instance_double(Process::Status, success?: true)])

      delete "/opencode/sessions/ses_1", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["output"]).to include("deleted")
    end

    it "returns 422 with stderr when the CLI call fails" do
      allow(OpencodeCli).to receive(:exec).with("session", "delete", "missing")
        .and_return(["", "session not found\n", instance_double(Process::Status, success?: false)])

      delete "/opencode/sessions/missing", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["output"]).to include("not found")
    end
  end
end
