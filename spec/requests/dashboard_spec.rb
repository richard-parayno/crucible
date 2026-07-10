# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { user.default_workspace }
  let(:runtime_definition) { create(:runtime_definition, kind: "codex", name: "Codex") }

  before { sign_in_as(user) }

  it "renders agent counts with running agents" do
    secondary_workspace = create(:workspace, user:, name: "Client work")
    running_agent = create(
      :runtime_instance,
      workspace: secondary_workspace,
      runtime_definition:,
      name: "Codex running",
      status: "running",
      container_name: "crucible-codex-1",
      started_at: 10.minutes.ago
    )
    create(:runtime_instance, workspace:, runtime_definition:, status: "stopped")
    create(:runtime_instance, workspace: create(:user).default_workspace, status: "running")

    get dashboard_path

    expect(response).to have_http_status(:success)
    expect(inertia).to be_inertia_response
    expect(inertia).to render_component("dashboard/index")
    expect(inertia.props.fetch("agent_count")).to eq(2)
    expect(inertia.props.fetch("running_agents")).to contain_exactly(
      hash_including(
        "id" => running_agent.id,
        "name" => "Codex running",
        "status" => "running",
        "runtime_name" => "Codex",
        "container_name" => "crucible-codex-1",
        "workspace" => hash_including("id" => secondary_workspace.id, "name" => "Client work")
      )
    )
  end
end
