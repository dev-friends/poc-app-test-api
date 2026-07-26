require "rails_helper"

RSpec.describe "Opencode", type: :request do
  describe "GET /opencode/models" do
    it "splits the plain-text model list into an array" do
      allow(OpencodeCli).to receive(:exec).with("models")
        .and_return(["opencode/claude-sonnet-5\nopencode/claude-opus-5\n", "", instance_double(Process::Status, success?: true)])

      get "/opencode/models", headers: auth_headers

      expect(response.parsed_body["models"]).to eq(%w[opencode/claude-sonnet-5 opencode/claude-opus-5])
    end

    it "filters by provider when given" do
      allow(OpencodeCli).to receive(:exec).with("models", "opencode")
        .and_return(["opencode/claude-sonnet-5\n", "", instance_double(Process::Status, success?: true)])

      get "/opencode/models", params: { provider: "opencode" }, headers: auth_headers

      expect(response.parsed_body["models"]).to eq(["opencode/claude-sonnet-5"])
    end
  end

  describe "GET /opencode/agents" do
    it "returns the raw agent list output" do
      allow(OpencodeCli).to receive(:exec).with("agent", "list")
        .and_return(["build (primary)\n", "", instance_double(Process::Status, success?: true)])

      get "/opencode/agents", headers: auth_headers

      expect(response.parsed_body["output"]).to include("build")
    end
  end
end
