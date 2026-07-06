# frozen_string_literal: true

class CreateRuntimeDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :runtime_definitions do |t|
      t.string :kind
      t.string :name
      t.text :description
      t.string :container_image
      t.text :default_command
      t.json :default_env
      t.json :config_schema
      t.boolean :active

      t.timestamps
    end
  end
end
