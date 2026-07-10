# frozen_string_literal: true

class RuntimeInstancesController < InertiaController
  before_action :set_workspace
  before_action :set_runtime_instance, only: %i[start stop restart check_health]

  def start
    StartRuntimeInstanceJob.perform_later(@runtime_instance)
    redirect_to agent_path(@runtime_instance), notice: "Runtime start queued."
  end

  def stop
    StopRuntimeInstanceJob.perform_later(@runtime_instance)
    redirect_to agent_path(@runtime_instance), notice: "Runtime stop queued."
  end

  def restart
    RestartRuntimeInstanceJob.perform_later(@runtime_instance)
    redirect_to agent_path(@runtime_instance), notice: "Runtime restart queued."
  end

  def check_health
    CheckRuntimeInstanceHealthJob.perform_later(@runtime_instance)
    redirect_to agent_path(@runtime_instance), notice: "Health check queued."
  end

  private

  def set_workspace
    @workspace = Current.session.user.workspaces.find(params[:workspace_id])
  end

  def set_runtime_instance
    @runtime_instance = @workspace.runtime_instances.find(params[:id])
  end
end
