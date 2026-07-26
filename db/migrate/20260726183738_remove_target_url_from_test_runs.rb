class RemoveTargetUrlFromTestRuns < ActiveRecord::Migration[8.1]
  def change
    remove_column :test_runs, :target_url, :string
  end
end
