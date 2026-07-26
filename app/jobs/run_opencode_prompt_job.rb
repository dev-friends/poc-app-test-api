class RunOpencodePromptJob < ApplicationJob
  queue_as :opencode_runs

  def perform(opencode_run_id)
    run = OpencodeRun.find(opencode_run_id)
    run.update!(status: :running, started_at: Time.current)

    args = ["run", run.prompt, "--format", "json"]
    args += ["--agent", run.agent] if run.agent.present?
    args += ["--model", run.model] if run.model.present?
    args += ["--session", run.continue_session_id] if run.continue_session_id.present?

    stdout, stderr, status = OpencodeCli.exec(*args)

    events = stdout.each_line.filter_map { |line| JSON.parse(line) rescue nil }
    text = events.select { |e| e["type"] == "text" }.map { |e| e.dig("part", "text") }.join
    finish = events.reverse.find { |e| e["type"] == "step_finish" }
    session_id = events.find { |e| e["sessionID"] }&.dig("sessionID")

    run.update!(
      status: status.success? ? :completed : :failed,
      finished_at: Time.current,
      session_id: session_id,
      output_text: text,
      raw_events: stdout,
      cost: finish&.dig("part", "cost"),
      input_tokens: finish&.dig("part", "tokens", "input"),
      output_tokens: finish&.dig("part", "tokens", "output"),
      error_message: status.success? ? nil : stderr.presence
    )
  rescue => e
    run.update!(status: :failed, finished_at: Time.current, error_message: "#{e.class}: #{e.message}")
  end
end
