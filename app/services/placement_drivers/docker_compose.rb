# frozen_string_literal: true

require "json"

module PlacementDrivers
  class DockerCompose
    def initialize(command_runner: CommandRunner.new, project_writer: ComposeProjectWriter.new)
      @command_runner = command_runner
      @project_writer = project_writer
    end

    def start(runtime_instance, adapter_spec)
      project = @project_writer.write(runtime_instance, adapter_spec)
      ensure_previous_project_removed(project)

      result = @command_runner.call(*compose_command(project, "up", "--detach", project.service_name))
      raise command_error("start", result, runtime_instance) unless result.success?

      runtime_instance.running!(external_id: project.project_name, container_name: project.service_name)
      record_event(runtime_instance, "info", "Started docker compose project #{project.project_name} service #{project.service_name}.")
      capture_recent_logs(runtime_instance)
    end

    def stop(runtime_instance)
      runtime_instance.stopping!
      project = @project_writer.project_for(runtime_instance)

      unless project.compose_path.exist?
        runtime_instance.stopped!("No compose project was recorded for this runtime.")
        record_event(runtime_instance, "warn", "Stopped without a recorded compose project.")
        return
      end

      result = @command_runner.call(*compose_command(project, "stop", project.service_name))
      unless result.success?
        record_event(runtime_instance, "warn", sanitized_message(runtime_instance, result.stderr.presence || "Compose stop returned a non-zero status."))
      end

      runtime_instance.stopped!("Compose project stopped.")
      record_event(runtime_instance, "info", "Stopped docker compose project #{project.project_name} service #{project.service_name}.")
    end

    def restart(runtime_instance)
      project = @project_writer.project_for(runtime_instance)
      result = @command_runner.call(*compose_command(project, "restart", project.service_name))
      raise command_error("restart", result, runtime_instance) unless result.success?

      runtime_instance.update!(status: "running", last_heartbeat_at: Time.current, status_message: nil)
      record_event(runtime_instance, "info", "Restarted docker compose project #{project.project_name} service #{project.service_name}.")
      capture_recent_logs(runtime_instance)
    end

    def status(runtime_instance, adapter)
      project = @project_writer.project_for(runtime_instance)
      return ["stopped", "No compose project has been started yet."] unless project.compose_path.exist?

      result = @command_runner.call(*compose_command(project, "ps", "--all", "--format", "json", project.service_name))
      return ["failed", result.stderr] unless result.success?

      state = compose_state(result.stdout, project.service_name)
      return ["stopped", "Compose service has not been started yet."] if state.blank?

      adapter.health_status(runtime_instance, state)
    end

    def capture_recent_logs(runtime_instance)
      project = @project_writer.project_for(runtime_instance)
      return unless project.compose_path.exist?

      result = @command_runner.call(*compose_command(project, "logs", "--tail", "100", project.service_name))
      return unless result.success?

      result.stdout.lines.last(100).each do |line|
        message = line.strip
        record_event(runtime_instance, "info", sanitized_message(runtime_instance, message)) if message.present?
      end
    end

    def logs(runtime_instance)
      capture_recent_logs(runtime_instance)
    end

    private

    def compose_command(project, *args)
      [
        "docker",
        "compose",
        "-p",
        project.project_name,
        "-f",
        project.compose_path.to_s,
        "--env-file",
        project.env_path.to_s,
        *args
      ]
    end

    def ensure_previous_project_removed(project)
      @command_runner.call(*compose_command(project, "down", "--remove-orphans"))
    end

    def compose_state(stdout, service_name)
      payload = JSON.parse(stdout.presence || "[]")
      rows = payload.is_a?(Array) ? payload : [payload]
      row = rows.find { |candidate| candidate["Service"] == service_name } || rows.first
      return if row.blank?

      row["State"].presence || row["Status"].to_s.split.first&.downcase
    rescue JSON::ParserError
      stdout.strip
    end

    def record_event(runtime_instance, level, message)
      runtime_instance.runtime_events.create!(level:, message:, occurred_at: Time.current)
    end

    def command_error(action, result, runtime_instance)
      message = result.stderr.presence || result.stdout.presence || "Unknown compose #{action} failure"
      RuntimeOrchestration::CommandFailed.new(sanitized_message(runtime_instance, message))
    end

    def sanitized_message(runtime_instance, message)
      known_env_values(runtime_instance).reduce(message.to_s) do |sanitized, value|
        sanitized.gsub(value, "[FILTERED]")
      end
    end

    def known_env_values(runtime_instance)
      runtime_instance.runtime_definition.default_env
        .merge(runtime_instance.env)
        .values
        .map(&:to_s)
        .select(&:present?)
        .uniq
    end
  end
end
