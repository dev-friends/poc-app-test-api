class CreateTestRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :test_runs do |t|
      t.string   :status, null: false, default: "pending"
      t.string   :target_url
      t.datetime :started_at
      t.datetime :finished_at
      t.integer  :total_count,   null: false, default: 0
      t.integer  :passed_count,  null: false, default: 0
      t.integer  :failed_count,  null: false, default: 0
      t.integer  :pending_count, null: false, default: 0
      t.text     :error_message

      t.timestamps
    end

    add_index :test_runs, :status

    # Ensures at most one active (pending/running) run exists at a time.
    # Indexing a constant expression (rather than the `status` column itself)
    # is required here: a unique index on `status` would only reject two rows
    # sharing the *same* value (two "pending"s), not one "pending" + one
    # "running" coexisting, which is exactly the case we need to prevent.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE UNIQUE INDEX index_test_runs_on_active_status
          ON test_runs ((1))
          WHERE status IN ('pending','running')
        SQL
      end
      dir.down do
        execute "DROP INDEX index_test_runs_on_active_status"
      end
    end
  end
end
