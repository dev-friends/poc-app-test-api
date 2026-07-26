class CreateOpencodeRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :opencode_runs do |t|
      t.string   :status, null: false, default: "pending"
      t.text     :prompt, null: false
      t.string   :agent
      t.string   :model
      t.string   :continue_session_id
      t.string   :session_id
      t.text     :output_text
      t.text     :raw_events
      t.float    :cost
      t.integer  :input_tokens
      t.integer  :output_tokens
      t.text     :error_message
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :opencode_runs, :status
  end
end
