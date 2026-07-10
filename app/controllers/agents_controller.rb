# frozen_string_literal: true

class AgentsController < InertiaController
  before_action :sync_runtime_definitions

  def index
    render inertia: AgentRuntimeInventory.new(user: Current.session.user).call
  end

  def new
    workspace = selected_workspace

    render inertia: {
      workspace: workspace.slice(:id, :name, :default_workspace),
      runtime_definitions: RuntimeDefinition.active.map { |runtime_definition| RuntimeInstanceSerializer.runtime_definition(runtime_definition) }
    }
  end

  def show
    runtime_instance = scoped_runtime_instances.find(params[:id])

    render inertia: {
      agent: RuntimeInstanceSerializer.instance(runtime_instance).merge(
        workspace: runtime_instance.workspace.slice(:id, :name)
      )
    }
  end

  def create
    @workspace = selected_workspace
    runtime_definition = RuntimeDefinition.active.find(params[:runtime_definition_id])
    runtime_instance = @workspace.runtime_instances.create!(
      runtime_definition:,
      name: params[:name].presence || runtime_definition.name,
      placement_kind: "docker_compose",
      container_runtime: "docker",
      env: parse_json_field(:env),
      config: parse_json_field(:config)
    )

    StartRuntimeInstanceJob.perform_later(runtime_instance)
    redirect_to agent_path(runtime_instance), notice: "Agent added and start queued."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_agent_path(workspace_id: @workspace&.id), inertia: {errors: e.record.errors}
  rescue JSON::ParserError => e
    redirect_to new_agent_path(workspace_id: @workspace&.id), inertia: {errors: {config: e.message}}
  end

  private

  def scoped_runtime_instances
    RuntimeInstance
      .joins(:workspace)
      .includes(:workspace, :runtime_definition, :environment_variables)
      .where(workspaces: {user_id: Current.session.user.id})
  end

  def selected_workspace
    return Current.session.user.workspaces.find(params[:workspace_id]) if params[:workspace_id].present?

    Current.session.user.ensure_default_workspace!
  end

  def parse_json_field(key)
    value = params[key]
    return {} if value.blank?
    return value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
    return value if value.is_a?(Hash)

    JSON.parse(value)
  end

  def sync_runtime_definitions
    RuntimeDefinitionSeeder.call
  end
end
