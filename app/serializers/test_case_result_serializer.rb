class TestCaseResultSerializer
  def initialize(result)
    @result = result
  end

  def as_json
    r = @result
    {
      id: r.id,
      full_description: r.full_description,
      description: r.description,
      file_path: r.file_path,
      line_number: r.line_number,
      status: r.status,
      run_time: r.run_time,
      target_url: r.target_url,
      error_message: r.error_message,
      error_backtrace: r.error_backtrace
    }
  end
end
