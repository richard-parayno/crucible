# frozen_string_literal: true

class CreateWorkspaces < ActiveRecord::Migration[8.1]
  def change
    create_table :workspaces do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
