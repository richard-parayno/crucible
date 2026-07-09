# frozen_string_literal: true

class CreateEnvironmentVariables < ActiveRecord::Migration[8.1]
  def change
    create_table :environment_variables do |t|
      t.string :scope, null: false
      t.string :key, null: false
      t.text :value, null: false
      t.boolean :sensitive, null: false, default: false
      t.boolean :enabled, null: false, default: true
      t.references :runtime_instance, null: true, foreign_key: true

      t.timestamps

      t.check_constraint "scope IN ('system', 'runtime_instance')", name: "environment_variables_scope_check"
      t.check_constraint <<~SQL.squish, name: "environment_variables_scope_runtime_instance_check"
        (scope = 'system' AND runtime_instance_id IS NULL)
        OR (scope = 'runtime_instance' AND runtime_instance_id IS NOT NULL)
      SQL
    end

    add_index :environment_variables, [:scope, :key],
      unique: true,
      where: "scope = 'system' AND runtime_instance_id IS NULL",
      name: "index_environment_variables_on_system_key"

    add_index :environment_variables, [:runtime_instance_id, :key],
      unique: true,
      where: "scope = 'runtime_instance' AND runtime_instance_id IS NOT NULL",
      name: "index_environment_variables_on_runtime_instance_key"
  end
end
