# frozen_string_literal: true

class Workspace < ApplicationRecord
  belongs_to :user
  has_many :runtime_instances, dependent: :destroy

  scope :default_workspace, -> { where(default_workspace: true) }

  before_validation :mark_first_workspace_as_default, on: :create
  before_save :clear_other_default_workspaces, if: :default_workspace?

  validates :name, presence: true
  validates :default_workspace, inclusion: {in: [true, false]}

  private

  def mark_first_workspace_as_default
    self.default_workspace = true if user && !user.workspaces.exists?
  end

  def clear_other_default_workspaces
    user.workspaces.where.not(id:).default_workspace.update_all(default_workspace: false, updated_at: Time.current)
  end
end
