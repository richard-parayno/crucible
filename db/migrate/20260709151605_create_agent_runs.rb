# frozen_string_literal: true

class CreateAgentRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_runs do |t|
      t.references :runtime_instance, null: false, foreign_key: true
      t.text :prompt
      t.text :command, null: false
      t.string :status, null: false, default: "queued"
      t.integer :exit_code
      t.text :output
      t.datetime :started_at
      t.datetime :finished_at
      t.text :status_message

      t.timestamps
    end

    add_index :agent_runs, [:runtime_instance_id, :created_at]
    add_index :agent_runs, :status
  end
end
