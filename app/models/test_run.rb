class TestRun < ApplicationRecord
  has_many :test_case_results, dependent: :destroy

  enum :status, { pending: "pending", running: "running", completed: "completed", failed: "failed" }

  scope :active,   -> { where(status: [:pending, :running]) }
  scope :finished, -> { where(status: [:completed, :failed]) }

  def duration_seconds
    return nil unless started_at && finished_at

    (finished_at - started_at).round(2)
  end
end
