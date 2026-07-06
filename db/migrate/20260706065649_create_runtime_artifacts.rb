# frozen_string_literal: true

class CreateRuntimeArtifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :runtime_artifacts do |t|
      t.references :runtime_instance, null: false, foreign_key: true
      t.string :kind
      t.string :path
      t.json :metadata

      t.timestamps
    end
  end
end
