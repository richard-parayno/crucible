# frozen_string_literal: true

module PlacementDrivers
  class LocalContainer
    def initialize(command_runner: CommandRunner.new)
      @command_runner = command_runner
    end

    def start(runtime_instance, adapter_spec)
      container_name = runtime_instance.container_name.presence || build_container_name(runtime_instance)
      ensure_previous_container_removed(runtime_instance.container_runtime, container_name)

      result = @command_runner.call(*run_command(runtime_instance.container_runtime, container_name, adapter_spec))
      raise command_error("start", result) unless result.success?

      runtime_instance.running!(external_id: result.stdout.strip, container_name:)
      record_event(runtime_instance, "info", "Started #{runtime_instance.container_runtime} container #{container_name}")
      capture_recent_logs(runtime_instance)
    end

    def stop(runtime_instance)
      runtime_instance.stopping!

      if runtime_instance.container_name.blank?
        runtime_instance.stopped!("No local container was recorded for this runtime.")
        record_event(runtime_instance, "warn", "Stopped without a recorded container name.")
        return
      end

      stop_result = @command_runner.call(runtime_instance.container_runtime, "stop", runtime_instance.container_name)
      unless stop_result.success?
        record_event(runtime_instance, "warn", stop_result.stderr.presence || "Container stop returned a non-zero status.")
      end

      runtime_instance.stopped!("Container stopped.")
      record_event(runtime_instance, "info", "Stopped container #{runtime_instance.container_name}.")
    end

    def status(runtime_instance, adapter)
      return ["stopped", "No container has been started yet."] if runtime_instance.container_name.blank?

      result = @command_runner.call(
        runtime_instance.container_runtime,
        "inspect",
        "--format",
        "{{.State.Status}}",
        runtime_instance.container_name
      )

      return ["failed", result.stderr] unless result.success?

      adapter.health_status(runtime_instance, result.stdout.strip)
    end

    def capture_recent_logs(runtime_instance)
      return if runtime_instance.container_name.blank?

      result = @command_runner.call(runtime_instance.container_runtime, "logs", "--tail", "100", runtime_instance.container_name)
      return unless result.success?

      result.stdout.lines.last(100).each do |line|
        record_event(runtime_instance, "info", line.strip) if line.strip.present?
      end
    end

    private

    def run_command(container_runtime, container_name, adapter_spec)
      [
        container_runtime,
        "run",
        "--detach",
        "--name",
        container_name,
        "--workdir",
        adapter_spec.workdir,
        *adapter_spec.labels.flat_map { |key, value| ["--label", "#{key}=#{value}"] },
        *adapter_spec.env.flat_map { |key, value| ["--env", "#{key}=#{value}"] },
        adapter_spec.image,
        "sh",
        "-lc",
        adapter_spec.command
      ]
    end

    def ensure_previous_container_removed(container_runtime, container_name)
      @command_runner.call(container_runtime, "rm", "--force", container_name)
    end

    def build_container_name(runtime_instance)
      "crucible-#{runtime_instance.id}-#{runtime_instance.runtime_definition.kind}"
    end

    def record_event(runtime_instance, level, message)
      runtime_instance.runtime_events.create!(level:, message:, occurred_at: Time.current)
    end

    def command_error(action, result)
      message = result.stderr.presence || result.stdout.presence || "Unknown container #{action} failure"
      RuntimeOrchestration::CommandFailed.new(message)
    end
  end
end
