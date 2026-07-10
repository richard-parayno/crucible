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
      runtime_definitions: supported_runtime_definitions,
      import_defaults: import_defaults
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
      env: runtime_env,
      config: runtime_config(runtime_definition)
    )

    StartRuntimeInstanceJob.perform_later(runtime_instance)
    redirect_to agent_path(runtime_instance), notice: "Agent added and start queued."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_agent_path(workspace_id: @workspace&.id), inertia: {errors: e.record.errors}
  rescue JSON::ParserError => e
    redirect_to new_agent_path(workspace_id: @workspace&.id), inertia: {errors: {config: e.message}}
  rescue ArgumentError => e
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

  def import_defaults
    params.permit(
      :runtime_definition_id,
      :kind,
      :name,
      :template_mode,
      :host_binary_path,
      :command,
      :working_directory
    ).to_h.compact_blank
  end

  def runtime_config(runtime_definition)
    return parse_json_field(:config) if params[:config].present?

    template = AgentCatalog.template_for(runtime_definition.kind, params[:template_mode]) ||
      AgentCatalog.template_for(runtime_definition.kind, AgentCatalog.default_template_mode_for(runtime_definition.kind))

    {
      "template_mode" => params[:template_mode].presence || template&.fetch(:mode),
      "container_image" => params[:container_image].presence || template&.fetch(:container_image, nil) || runtime_definition.container_image,
      "command" => params[:command].presence || template&.fetch(:default_command, nil) || runtime_definition.default_command,
      "host_binary_path" => params[:host_binary_path].presence,
      "config_volume_enabled" => boolean_param(:config_volume_enabled, default: true),
      "config_volume_name" => params[:config_volume_name].presence,
      "config_mount_path" => params[:config_mount_path].presence || template&.fetch(:config_mount_path, nil),
      "working_directory" => params[:working_directory].presence
    }.compact
  end

  def runtime_env
    return parse_json_field(:env) if params[:env].present?

    params[:env_lines].to_s.lines.each_with_object({}) do |line, env|
      stripped = line.strip
      next if stripped.blank?

      key, value = stripped.split("=", 2)
      raise ArgumentError, "Environment variables must use KEY=value lines." if key.blank? || value.nil?
      raise ArgumentError, "#{key} is not a valid environment variable name." unless key.match?(EnvironmentVariable::KEY_FORMAT)

      env[key] = value
    end
  end

  def boolean_param(key, default:)
    value = params[key]
    return default if value.nil?

    value = value.last if value.is_a?(Array)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def supported_runtime_definitions
    RuntimeDefinition.supported_for_add_agent.map { |runtime_definition| RuntimeInstanceSerializer.runtime_definition(runtime_definition) }
  end

  def sync_runtime_definitions
    RuntimeDefinitionSeeder.call
  end
end
