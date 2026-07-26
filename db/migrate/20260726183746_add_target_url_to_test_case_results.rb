class AddTargetUrlToTestCaseResults < ActiveRecord::Migration[8.1]
  def change
    add_column :test_case_results, :target_url, :string
  end
end
