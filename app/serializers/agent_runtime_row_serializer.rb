# frozen_string_literal: true

class AgentRuntimeRowSerializer
  class << self
    def detected(command:, name:, kind:, executable_path:, working_directory:)
      {
        id: "detected:#{command}",
        row_id: "detected:#{command}",
        source: "auto_detected",
        kind:,
        name:,
        runtime_kind: kind,
        runtime_name: name,
        executable_command: command,
        executable_path:,
        executable: {
          command:,
          path: executable_path,
          status: "available"
        },
        working_directory:,
        token_usage: nil,
        run_usage: nil,
        status: "available",
        workspace: nil,
        last_activity_at: nil,
        agent_path: nil,
        runtime_instance_id: nil,
        runtime_definition_id: nil,
        links: {}
      }
    end

    def manual(runtime_instance)
      latest_agent_run_at = latest_agent_run_at(runtime_instance)
      executable = manual_executable(runtime_instance)

      {
        id: "runtime_instance:#{runtime_instance.id}",
        row_id: "runtime_instance:#{runtime_instance.id}",
        source: "manual",
        kind: runtime_instance.runtime_definition.kind,
        name: runtime_instance.name,
        runtime_kind: runtime_instance.runtime_definition.kind,
        runtime_name: runtime_instance.runtime_definition.name,
        executable_command: executable.fetch(:command),
        executable_path: executable.fetch(:path),
        executable:,
        working_directory: working_directory(runtime_instance),
        token_usage: nil,
        run_usage: run_usage(runtime_instance, latest_agent_run_at),
        status: runtime_instance.status,
        workspace: runtime_instance.workspace.slice(:id, :name),
        last_activity_at: last_activity_at(runtime_instance, latest_agent_run_at)&.iso8601,
        agent_path: Rails.application.routes.url_helpers.agent_path(runtime_instance),
        runtime_instance_id: runtime_instance.id,
        runtime_definition_id: runtime_instance.runtime_definition_id,
        links: {
          show: Rails.application.routes.url_helpers.agent_path(runtime_instance),
          workspace: Rails.application.routes.url_helpers.dashboard_path(workspace_id: runtime_instance.workspace_id)
        }
      }
    end

    private

    def manual_executable(runtime_instance)
      command = runtime_instance.config["command"].presence || runtime_instance.runtime_definition.default_command.presence
      path = runtime_instance.config["executable_path"].presence

      {
        command:,
        path:,
        status: path.present? ? "configured" : nil
      }
    end

    def working_directory(runtime_instance)
      runtime_instance.config["working_directory"].presence ||
        runtime_instance.config["workdir"].presence ||
        ComposeProjectPresenter.call(runtime_instance)&.fetch(:directory_path)
    end

    def run_usage(runtime_instance, latest_agent_run_at)
      agent_runs = runtime_instance.agent_runs

      {
        total_count: agent_runs.size,
        completed_count: agent_runs.count { |agent_run| agent_run.status.in?(%w[succeeded failed canceled]) },
        running_count: agent_runs.count { |agent_run| agent_run.status == "running" },
        last_run_at: latest_agent_run_at&.iso8601
      }
    end

    def latest_agent_run_at(runtime_instance)
      runtime_instance.agent_runs.map { |agent_run| agent_run.finished_at || agent_run.started_at || agent_run.created_at }.compact.max
    end

    def last_activity_at(runtime_instance, latest_agent_run_at)
      [
        runtime_instance.last_heartbeat_at,
        runtime_instance.started_at,
        runtime_instance.stopped_at,
        latest_agent_run_at,
        runtime_instance.updated_at
      ].compact.max
    end
  end
end
