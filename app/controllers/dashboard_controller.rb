# frozen_string_literal: true

class DashboardController < InertiaController
  def index
    runtime_instances = RuntimeInstance
      .joins(:workspace)
      .includes(:workspace, :runtime_definition)
      .where(workspaces: {user_id: Current.session.user.id})

    render inertia: {
      agent_count: runtime_instances.count,
      running_agents: runtime_instances
        .where(status: "running")
        .order(started_at: :desc, created_at: :desc)
        .map { |runtime_instance| RuntimeInstanceSerializer.dashboard_agent(runtime_instance) }
    }
  end
end
