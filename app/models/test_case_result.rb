class TestCaseResult < ApplicationRecord
  belongs_to :test_run

  enum :status, { passed: "passed", failed: "failed", pending: "pending" }
end
