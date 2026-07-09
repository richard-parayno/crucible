# frozen_string_literal: true

class RuntimeInstancesController < InertiaController
  before_action :set_workspace
  before_action :set_runtime_instance, only: %i[start stop restart check_health]

  def create
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
    redirect_to workspace_path(@workspace, runtime_instance_id: runtime_instance.id), notice: "Runtime added and start queued."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to workspace_path(@workspace), inertia: {errors: e.record.errors}
  rescue JSON::ParserError => e
    redirect_to workspace_path(@workspace), inertia: {errors: {config: e.message}}
  end

  def start
    StartRuntimeInstanceJob.perform_later(@runtime_instance)
    redirect_to workspace_path(@workspace, runtime_instance_id: @runtime_instance.id), notice: "Runtime start queued."
  end

  def stop
    StopRuntimeInstanceJob.perform_later(@runtime_instance)
    redirect_to workspace_path(@workspace, runtime_instance_id: @runtime_instance.id), notice: "Runtime stop queued."
  end

  def restart
    RestartRuntimeInstanceJob.perform_later(@runtime_instance)
    redirect_to workspace_path(@workspace, runtime_instance_id: @runtime_instance.id), notice: "Runtime restart queued."
  end

  def check_health
    CheckRuntimeInstanceHealthJob.perform_later(@runtime_instance)
    redirect_to workspace_path(@workspace, runtime_instance_id: @runtime_instance.id), notice: "Health check queued."
  end

  private

  def set_workspace
    @workspace = Current.session.user.workspaces.find(params[:workspace_id])
  end

  def set_runtime_instance
    @runtime_instance = @workspace.runtime_instances.find(params[:id])
  end

  def parse_json_field(key)
    value = params[key]
    return {} if value.blank?
    return value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
    return value if value.is_a?(Hash)

    JSON.parse(value)
  end
end
