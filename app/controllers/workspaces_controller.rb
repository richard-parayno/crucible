# frozen_string_literal: true

class WorkspacesController < InertiaController
  before_action :sync_runtime_definitions

  def index
    workspace = Current.session.user.workspaces.order(created_at: :asc).first
    redirect_to(workspace ? workspace_path(workspace) : create_default_workspace_path)
  end

  def show
    render inertia: {
      workspace: RuntimeInstanceSerializer.workspace(current_user_workspaces.find(params[:id])),
      workspaces: current_user_workspaces.order(created_at: :asc).map { |workspace| workspace.slice(:id, :name) },
      runtime_definitions: RuntimeDefinition.active.map { |runtime_definition| RuntimeInstanceSerializer.runtime_definition(runtime_definition) },
      system_environment_variables: EnvironmentVariable.system_variables.order(:key).map(&:safe_attributes),
      selected_runtime_instance_id: params[:runtime_instance_id]&.to_i,
      host_capabilities: HostCapabilities.new.call
    }
  end

  def create
    workspace = current_user_workspaces.create!(workspace_params)
    redirect_to workspace_path(workspace), notice: "Workspace created."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to workspaces_path, inertia: {errors: e.record.errors}
  end

  private

  def current_user_workspaces
    Current.session.user.workspaces
  end

  def workspace_params
    params.permit(:name, :description)
  end

  def create_default_workspace_path
    workspace = current_user_workspaces.create!(name: "Local workspace")
    workspace_path(workspace)
  end

  def sync_runtime_definitions
    RuntimeDefinitionSeeder.call
  end
end
