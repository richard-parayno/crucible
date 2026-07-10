# frozen_string_literal: true

class AddDefaultToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :default_workspace, :boolean, null: false, default: false
    add_index :workspaces,
      :user_id,
      unique: true,
      where: "default_workspace",
      name: "index_workspaces_on_user_default_workspace"

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE workspaces
          SET default_workspace = TRUE
          WHERE id IN (
            SELECT MIN(id)
            FROM workspaces
            GROUP BY user_id
          )
        SQL
      end
    end
  end
end
