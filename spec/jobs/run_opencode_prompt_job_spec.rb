require "rails_helper"

RSpec.describe RunOpencodePromptJob do
  let(:run) { OpencodeRun.create!(status: :pending, prompt: "reply with exactly: pong") }

  def ndjson(*events)
    events.map(&:to_json).join("\n")
  end

  it "marks the run completed and extracts text/session_id/cost/tokens" do
    stdout = ndjson(
      { "type" => "step_start", "sessionID" => "ses_abc123", "part" => {} },
      { "type" => "text", "sessionID" => "ses_abc123", "part" => { "text" => "pong" } },
      { "type" => "step_finish", "sessionID" => "ses_abc123",
        "part" => { "cost" => 0.0327, "tokens" => { "input" => 2, "output" => 4 } } }
    )
    allow(OpencodeCli).to receive(:exec)
      .and_return([stdout, "", instance_double(Process::Status, success?: true)])

    described_class.perform_now(run.id)

    run.reload
    expect(run.status).to eq("completed")
    expect(run.output_text).to eq("pong")
    expect(run.session_id).to eq("ses_abc123")
    expect(run.cost).to eq(0.0327)
    expect(run.input_tokens).to eq(2)
    expect(run.output_tokens).to eq(4)
  end

  it "marks the run failed when the process exits non-zero" do
    allow(OpencodeCli).to receive(:exec)
      .and_return(["", "boom", instance_double(Process::Status, success?: false)])

    described_class.perform_now(run.id)

    run.reload
    expect(run.status).to eq("failed")
    expect(run.error_message).to eq("boom")
  end

  it "passes agent/model/continue_session_id through as CLI flags" do
    run.update!(agent: "build", model: "opencode/claude-sonnet-5", continue_session_id: "ses_prev")

    expect(OpencodeCli).to receive(:exec).with(
      "run", run.prompt, "--format", "json",
      "--agent", "build", "--model", "opencode/claude-sonnet-5", "--session", "ses_prev"
    ).and_return(["", "", instance_double(Process::Status, success?: true)])

    described_class.perform_now(run.id)
  end
end
