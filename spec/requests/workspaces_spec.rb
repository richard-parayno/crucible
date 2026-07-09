# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Workspaces", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in_as(user)
    allow(HostCapabilities).to receive(:new).and_return(
      instance_double(HostCapabilities, call: {"container" => {"docker" => {"status" => "supported"}}})
    )
  end

  it "creates a default workspace when opening the local supervisor" do
    get workspaces_path

    expect(response).to redirect_to(workspace_path(user.workspaces.first))
    expect(user.workspaces.first.name).to eq("Local workspace")
  end

  it "renders the workspace page with runtime props" do
    workspace = create(:workspace, user:, name: "Local lab")
    runtime_instance = create(:runtime_instance, workspace:)
    create(:environment_variable, :sensitive, key: "SYSTEM_SECRET", value: "hidden")
    create(:environment_variable, :runtime_instance_scope, :sensitive, runtime_instance:, key: "RUNTIME_SECRET", value: "override")

    get workspace_path(workspace, runtime_instance_id: runtime_instance.id)

    expect(response).to have_http_status(:success)
    expect(inertia).to be_inertia_response
    expect(inertia).to render_component("workspaces/show")
    props = inertia.props
    workspace_props = props.fetch("workspace")

    expect(workspace_props.fetch("id")).to eq(workspace.id)
    expect(workspace_props.fetch("name")).to eq("Local lab")
    expect(workspace_props).to have_key("runtime_instances")
    expect(workspace_props.fetch("runtime_instances").first.fetch("environment_variables")).to include(
      hash_including("key" => "RUNTIME_SECRET", "value" => EnvironmentVariable::MASKED_VALUE)
    )
    expect(props.fetch("system_environment_variables")).to include(
      hash_including("key" => "SYSTEM_SECRET", "value" => EnvironmentVariable::MASKED_VALUE)
    )
    expect(props.fetch("selected_runtime_instance_id")).to eq(runtime_instance.id)
    expect(props.fetch("workspaces")).to include(hash_including("id" => workspace.id))
    expect(props.fetch("runtime_definitions")).not_to be_empty
    expect(props).to have_key("host_capabilities")
  end
end
