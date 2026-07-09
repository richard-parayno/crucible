# frozen_string_literal: true

class AgentRunSerializer
  class << self
    def run(agent_run)
      {
        id: agent_run.id,
        runtime_instance_id: agent_run.runtime_instance_id,
        prompt: agent_run.prompt,
        command: agent_run.command,
        status: agent_run.status,
        exit_code: agent_run.exit_code,
        output: agent_run.output,
        status_message: agent_run.status_message,
        started_at: agent_run.started_at&.iso8601,
        finished_at: agent_run.finished_at&.iso8601,
        created_at: agent_run.created_at.iso8601
      }
    end
  end
end
