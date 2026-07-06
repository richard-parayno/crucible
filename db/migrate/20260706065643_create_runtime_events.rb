# frozen_string_literal: true

class CreateRuntimeEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :runtime_events do |t|
      t.references :runtime_instance, null: false, foreign_key: true
      t.string :level
      t.text :message
      t.json :metadata
      t.datetime :occurred_at

      t.timestamps
    end
  end
end
