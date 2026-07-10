# frozen_string_literal: true

class RuntimeInstanceSerializer
  class << self
    def workspace(workspace)
      {
        id: workspace.id,
        name: workspace.name,
        description: workspace.description,
        runtime_instances: workspace.runtime_instances.includes(:runtime_definition, :environment_variables).order(created_at: :desc).map do |runtime_instance|
          instance(runtime_instance)
        end
      }
    end

    def runtime_definition(runtime_definition)
      {
        id: runtime_definition.id,
        kind: runtime_definition.kind,
        name: runtime_definition.name,
        description: runtime_definition.description,
        container_image: runtime_definition.container_image,
        default_command: runtime_definition.default_command,
        config_schema: runtime_definition.config_schema
      }
    end

    def dashboard_agent(runtime_instance)
      {
        id: runtime_instance.id,
        name: runtime_instance.name,
        status: runtime_instance.status,
        runtime_kind: runtime_instance.runtime_definition.kind,
        runtime_name: runtime_instance.runtime_definition.name,
        container_name: runtime_instance.container_name,
        status_message: runtime_instance.status_message,
        started_at: runtime_instance.started_at&.iso8601,
        workspace: runtime_instance.workspace.slice(:id, :name)
      }
    end

    def instance(runtime_instance)
      {
        id: runtime_instance.id,
        name: runtime_instance.name,
        status: runtime_instance.status,
        placement_kind: runtime_instance.placement_kind,
        container_runtime: runtime_instance.container_runtime,
        container_name: runtime_instance.container_name,
        compose_project: ComposeProjectPresenter.call(runtime_instance),
        runtime_kind: runtime_instance.runtime_definition.kind,
        runtime_name: runtime_instance.runtime_definition.name,
        status_message: runtime_instance.status_message,
        started_at: runtime_instance.started_at&.iso8601,
        stopped_at: runtime_instance.stopped_at&.iso8601,
        last_heartbeat_at: runtime_instance.last_heartbeat_at&.iso8601,
        recent_agent_runs: runtime_instance.agent_runs.order(created_at: :desc).limit(10).map { |agent_run| AgentRunSerializer.run(agent_run) },
        environment_variables: runtime_instance.environment_variables.order(:key).map(&:safe_attributes),
        recent_events: runtime_instance.runtime_events.order(occurred_at: :desc).limit(50).reverse.map { |runtime_event| event(runtime_event) }
      }
    end

    def event(runtime_event)
      {
        id: runtime_event.id,
        level: runtime_event.level,
        message: runtime_event.message,
        metadata: runtime_event.metadata,
        occurred_at: runtime_event.occurred_at.iso8601
      }
    end
  end
end
