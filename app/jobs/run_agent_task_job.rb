# frozen_string_literal: true

class RunAgentTaskJob < ApplicationJob
  queue_as :default

  def perform(agent_run)
    AgentRuns::Executor.new.call(agent_run)
  end
end
