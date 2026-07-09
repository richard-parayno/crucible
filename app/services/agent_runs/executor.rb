# frozen_string_literal: true

module AgentRuns
  class Executor
    MAX_EVENT_OUTPUT_LINES = 100

    def initialize(driver_resolver: PlacementDrivers)
      @driver_resolver = driver_resolver
    end

    def call(agent_run)
      runtime_instance = agent_run.runtime_instance
      agent_run.running!
      record_event(agent_run, "info", "Agent run started.", phase: "started")

      driver = @driver_resolver.for(runtime_instance.placement_kind)
      raise RuntimeOrchestration::CommandFailed, "Placement driver #{runtime_instance.placement_kind} does not support command execution." unless driver.respond_to?(:exec)

      result = driver.exec(runtime_instance, agent_run.command)
      output = combined_output(runtime_instance, result)
      exit_code = exit_code_for(result)

      record_output_events(agent_run, result)

      if result.success?
        agent_run.succeeded!(exit_code:, output:)
        record_event(agent_run, "info", "Agent run completed successfully.", phase: "finished", exit_code:)
      else
        message = "Command exited with status #{exit_code}."
        agent_run.failed!(message, exit_code:, output:)
        record_event(agent_run, "error", message, phase: "finished", exit_code:)
      end
    rescue StandardError => e
      message = sanitized_message(agent_run.runtime_instance, e.message)
      agent_run.failed!(message) if agent_run.persisted? && agent_run.status != "failed"
      record_event(agent_run, "error", message, phase: "failed") if agent_run.persisted?
      raise
    end

    private

    def combined_output(runtime_instance, result)
      [
        sanitized_message(runtime_instance, result.stdout),
        sanitized_message(runtime_instance, result.stderr)
      ].select(&:present?).join("\n")
    end

    def record_output_events(agent_run, result)
      record_stream_events(agent_run, "stdout", result.stdout)
      record_stream_events(agent_run, "stderr", result.stderr, level: "error")
    end

    def record_stream_events(agent_run, stream, content, level: "info")
      sanitized_message(agent_run.runtime_instance, content)
        .to_s
        .lines
        .last(MAX_EVENT_OUTPUT_LINES)
        .each do |line|
          message = line.strip
          record_event(agent_run, level, message, phase: "output", stream:) if message.present?
        end
    end

    def record_event(agent_run, level, message, metadata = {})
      agent_run.runtime_instance.runtime_events.create!(
        level:,
        message:,
        occurred_at: Time.current,
        metadata: metadata.merge(agent_run_id: agent_run.id)
      )
    end

    def exit_code_for(result)
      return result.status.exitstatus if result.status.respond_to?(:exitstatus)

      result.success? ? 0 : 1
    end

    def sanitized_message(runtime_instance, message)
      known_env_values(runtime_instance).reduce(message.to_s) do |sanitized, value|
        sanitized.gsub(value, "[FILTERED]")
      end
    end

    def known_env_values(runtime_instance)
      EnvironmentVariableResolver.call(runtime_instance)
        .values
        .map(&:to_s)
        .select(&:present?)
        .uniq
    end
  end
end
