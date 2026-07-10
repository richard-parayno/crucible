# frozen_string_literal: true

class AgentRunsController < InertiaController
  before_action :set_workspace
  before_action :set_runtime_instance

  def create
    agent_run = @runtime_instance.agent_runs.create!(agent_run_attributes)
    RunAgentTaskJob.perform_later(agent_run)

    redirect_to agent_path(@runtime_instance), notice: "Agent run queued."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to agent_path(@runtime_instance), inertia: {errors: e.record.errors}
  end

  private

  def set_workspace
    @workspace = Current.session.user.workspaces.find(params[:workspace_id])
  end

  def set_runtime_instance
    @runtime_instance = @workspace.runtime_instances.find(params[:runtime_instance_id])
  end

  def agent_run_attributes
    prompt = params[:prompt].to_s
    command = params[:command].presence || prompt

    {
      prompt: prompt.presence,
      command:
    }
  end
end
