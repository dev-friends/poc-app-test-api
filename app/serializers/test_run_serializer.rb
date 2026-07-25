class TestRunSerializer
  def initialize(run)
    @run = run
  end

  def as_json(include_results: false)
    r = @run
    result = {
      id: r.id,
      status: r.status,
      target_url: r.target_url,
      started_at: r.started_at,
      finished_at: r.finished_at,
      duration_seconds: r.duration_seconds,
      total_count: r.total_count,
      passed_count: r.passed_count,
      failed_count: r.failed_count,
      pending_count: r.pending_count,
      error_message: r.error_message
    }

    if include_results
      result[:test_case_results] = r.test_case_results.map { |c| TestCaseResultSerializer.new(c).as_json }
    end

    result
  end
end
