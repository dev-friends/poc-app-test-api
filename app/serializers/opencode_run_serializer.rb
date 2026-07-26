class OpencodeRunSerializer
  def initialize(run)
    @run = run
  end

  def as_json
    r = @run
    {
      id: r.id,
      status: r.status,
      prompt: r.prompt,
      agent: r.agent,
      model: r.model,
      continue_session_id: r.continue_session_id,
      session_id: r.session_id,
      output_text: r.output_text,
      cost: r.cost,
      input_tokens: r.input_tokens,
      output_tokens: r.output_tokens,
      error_message: r.error_message,
      started_at: r.started_at,
      finished_at: r.finished_at,
      duration_seconds: r.duration_seconds
    }
  end
end
