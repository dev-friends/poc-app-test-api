class OpencodeRun < ApplicationRecord
  enum :status, { pending: "pending", running: "running", completed: "completed", failed: "failed" }

  def duration_seconds
    return nil unless started_at && finished_at

    (finished_at - started_at).round(2)
  end
end
