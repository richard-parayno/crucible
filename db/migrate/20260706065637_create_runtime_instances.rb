# frozen_string_literal: true

class CreateRuntimeInstances < ActiveRecord::Migration[8.1]
  def change
    create_table :runtime_instances do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :runtime_definition, null: false, foreign_key: true
      t.string :name
      t.string :status
      t.string :placement_kind
      t.string :container_runtime
      t.string :container_name
      t.string :external_id
      t.json :env
      t.json :config
      t.text :status_message
      t.datetime :started_at
      t.datetime :stopped_at
      t.datetime :last_heartbeat_at

      t.timestamps
    end
  end
end
