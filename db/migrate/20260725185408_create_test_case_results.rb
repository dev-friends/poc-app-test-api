class CreateTestCaseResults < ActiveRecord::Migration[8.1]
  def change
    create_table :test_case_results do |t|
      t.references :test_run, null: false, foreign_key: true
      t.string  :full_description, null: false
      t.string  :description
      t.string  :file_path
      t.integer :line_number
      t.string  :status, null: false
      t.float   :run_time
      t.text    :error_message
      t.text    :error_backtrace

      t.timestamps
    end

    add_index :test_case_results, [:test_run_id, :status]
  end
end
