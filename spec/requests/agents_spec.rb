# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Agents", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { user.default_workspace }
  let(:runtime_definition) { create(:runtime_definition) }

  before { sign_in_as(user) }

  it "renders the agent index with detected system runtimes and user's manual runtimes" do
    lookup = instance_double(ExecutablePathLookup)
    process_inventory = instance_double(HostAgentProcessInventory)
    allow(ExecutablePathLookup).to receive(:new).and_return(lookup)
    allow(HostAgentProcessInventory).to receive(:new).and_return(process_inventory)
    allow(lookup).to receive(:call).with("codex").and_return("/usr/local/bin/codex")
    allow(lookup).to receive(:call).with("claude").and_return(nil)
    allow(lookup).to receive(:call).with("opencode").and_return("/usr/local/bin/opencode")
    allow(lookup).to receive(:call).with("openclaw").and_return(nil)
    allow(lookup).to receive(:call).with("hermes-agent").and_return(nil)
    allow(process_inventory).to receive(:call).and_return(
      [
        HostAgentProcessInventory::ProcessRow.new(
          pid: 1234,
          user: "richard",
          command: "codex --ask",
          comm: "codex",
          executable: "/usr/local/bin/codex",
          cwd: "/home/richard/personal-dev/crucible",
          started_at: 20.minutes.ago,
          age_seconds: 1200,
          agent_kind: "codex",
          agent_name: "Codex",
          importable: true
        )
      ]
    )

    runtime_instance = create(
      :runtime_instance,
      workspace:,
      runtime_definition: create(:runtime_definition, kind: "codex", name: "Codex"),
      name: "Codex project runtime",
      status: "running",
      started_at: 15.minutes.ago,
      last_heartbeat_at: 5.minutes.ago,
      config: {
        "command" => "codex",
        "executable_path" => "/opt/crucible/bin/codex",
        "working_directory" => "/workspaces/crucible"
      }
    )
    create(:agent_run, runtime_instance:, status: "succeeded", finished_at: 4.minutes.ago)
    create(:agent_run, runtime_instance:, status: "running", started_at: 2.minutes.ago)
    create(:runtime_instance, workspace: create(:user).default_workspace)

    get agents_path

    expect(response).to have_http_status(:success)
    expect(inertia).to be_inertia_response
    expect(inertia).to render_component("agents/index")

    detected_runtimes = inertia.props.fetch("detected_runtimes")
    expect(detected_runtimes).to contain_exactly(
      include(
        "id" => "detected:codex",
        "row_id" => "detected:codex",
        "source" => "installed_binary",
        "kind" => "codex",
        "name" => "Codex",
        "working_directory" => Rails.root.to_s,
        "status" => "available",
        "executable_command" => "codex",
        "executable_path" => "/usr/local/bin/codex",
        "agent_path" => nil,
        "executable" => {
          "command" => "codex",
          "path" => "/usr/local/bin/codex",
          "status" => "available"
        }
      ),
      include(
        "id" => "detected:opencode",
        "row_id" => "detected:opencode",
        "source" => "installed_binary",
        "kind" => "opencode",
        "name" => "OpenCode",
        "working_directory" => Rails.root.to_s,
        "status" => "available",
        "executable_command" => "opencode",
        "executable_path" => "/usr/local/bin/opencode",
        "agent_path" => nil,
        "executable" => {
          "command" => "opencode",
          "path" => "/usr/local/bin/opencode",
          "status" => "available"
        }
      )
    )

    host_process = inertia.props.fetch("host_processes").sole
    expect(host_process).to include(
      "id" => "host_process:1234",
      "row_id" => "host_process:1234",
      "source" => "external_process",
      "kind" => "codex",
      "name" => "Codex",
      "pid" => 1234,
      "user" => "richard",
      "command" => "codex --ask",
      "working_directory" => "/home/richard/personal-dev/crucible",
      "executable_command" => "codex",
      "executable_path" => "/usr/local/bin/codex",
      "status" => "running",
      "age_seconds" => 1200,
      "importable" => true,
      "agent_path" => nil,
      "runtime_definition_id" => be_present,
      "executable" => {
        "command" => "codex",
        "path" => "/usr/local/bin/codex",
        "status" => "running"
      }
    )
    expect(host_process.fetch("import_path")).to include(
      "/agents/new",
      "kind=codex",
      "template_mode=host_binary"
    )

    manual_runtime = inertia.props.fetch("manual_runtimes").sole
    expect(manual_runtime).to include(
      "id" => "runtime_instance:#{runtime_instance.id}",
      "row_id" => "runtime_instance:#{runtime_instance.id}",
      "source" => "crucible_managed",
      "kind" => "codex",
      "name" => "Codex project runtime",
      "status" => "running",
      "working_directory" => "/workspaces/crucible",
      "executable_command" => "codex",
      "executable_path" => "/opt/crucible/bin/codex",
      "agent_path" => agent_path(runtime_instance),
      "runtime_instance_id" => runtime_instance.id,
      "runtime_definition_id" => runtime_instance.runtime_definition_id,
      "workspace" => hash_including("id" => workspace.id, "name" => workspace.name),
      "executable" => {
        "command" => "codex",
        "path" => "/opt/crucible/bin/codex",
        "status" => "configured"
      },
      "run_usage" => {
        "total_count" => 2,
        "completed_count" => 1,
        "running_count" => 1,
        "last_run_at" => be_present
      },
      "token_usage" => nil
    )
    expect(inertia.props.fetch("agent_runtimes").pluck("id")).to contain_exactly(
      "detected:codex",
      "detected:opencode",
      "host_process:1234",
      "runtime_instance:#{runtime_instance.id}"
    )
  end

  it "prefills the new agent page from import query params" do
    runtime_definition = create(:runtime_definition, kind: "codex", name: "Codex")

    get new_agent_path(
      workspace_id: workspace.id,
      runtime_definition_id: runtime_definition.id,
      kind: "codex",
      name: "Codex import",
      template_mode: "host_binary",
      host_binary_path: "/usr/local/bin/codex",
      command: "codex --ask",
      working_directory: "/workspaces/crucible"
    )

    expect(response).to have_http_status(:success)
    expect(inertia).to render_component("agents/new")
    expect(inertia.props.fetch("import_defaults")).to include(
      "runtime_definition_id" => runtime_definition.id.to_s,
      "kind" => "codex",
      "name" => "Codex import",
      "template_mode" => "host_binary",
      "host_binary_path" => "/usr/local/bin/codex",
      "command" => "codex --ask",
      "working_directory" => "/workspaces/crucible"
    )
  end

  it "renders the new agent page for the selected workspace" do
    runtime_definition

    get new_agent_path(workspace_id: workspace.id)

    expect(response).to have_http_status(:success)
    expect(inertia).to be_inertia_response
    expect(inertia).to render_component("agents/new")
    expect(inertia.props.fetch("workspace").fetch("id")).to eq(workspace.id)
    expect(inertia.props.fetch("runtime_definitions")).not_to be_empty
  end

  it "renders an agent page for a runtime instance in the user's workspace" do
    runtime_instance = create(
      :runtime_instance,
      workspace:,
      runtime_definition:,
      name: "Codex local",
      status: "running",
      started_at: 5.minutes.ago
    )

    get agent_path(runtime_instance)

    expect(response).to have_http_status(:success)
    expect(inertia).to be_inertia_response
    expect(inertia).to render_component("agents/show")
    expect(inertia.props.fetch("agent")).to include(
      "id" => runtime_instance.id,
      "name" => "Codex local",
      "status" => "running",
      "workspace" => hash_including("id" => workspace.id, "name" => workspace.name)
    )
  end

  it "creates a docker compose agent and queues a start job" do
    post agents_path, params: {
      workspace_id: workspace.id,
      runtime_definition_id: runtime_definition.id,
      name: "Local custom",
      template_mode: "custom",
      container_image: "alpine:latest",
      command: "echo ready",
      config_volume_enabled: "1",
      config_volume_name: "crucible_local_custom_config",
      config_mount_path: "/root/.config/custom-agent",
      env_lines: "TOKEN=redacted\nCRUCIBLE_MESSAGE=hello"
    }

    runtime_instance = workspace.runtime_instances.first
    expect(response).to redirect_to(agent_path(runtime_instance))
    expect(flash[:notice]).to eq("Agent added and start queued.")
    expect(runtime_instance).to have_attributes(
      name: "Local custom",
      placement_kind: "docker_compose",
      container_runtime: "docker",
      status: "pending"
    )
    expect(runtime_instance.config).to include(
      "template_mode" => "custom",
      "container_image" => "alpine:latest",
      "command" => "echo ready",
      "config_volume_enabled" => true,
      "config_volume_name" => "crucible_local_custom_config",
      "config_mount_path" => "/root/.config/custom-agent"
    )
    expect(runtime_instance.env).to eq("TOKEN" => "redacted", "CRUCIBLE_MESSAGE" => "hello")
    expect(StartRuntimeInstanceJob).to have_been_enqueued.with(runtime_instance)
  end

  it "redirects back to the new agent page when environment input is invalid" do
    expect do
      expect do
        post agents_path, params: {
          workspace_id: workspace.id,
          runtime_definition_id: runtime_definition.id,
          env_lines: "not valid"
        }
      end.not_to have_enqueued_job(StartRuntimeInstanceJob)
    end.not_to change { workspace.runtime_instances.count }

    expect(response).to redirect_to(new_agent_path(workspace_id: workspace.id))
  end

  it "does not allow adding agents to another user's workspace" do
    other_workspace = create(:user).default_workspace

    expect do
      post agents_path, params: {
        workspace_id: other_workspace.id,
        runtime_definition_id: runtime_definition.id
      }
    end.not_to change(RuntimeInstance, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "does not allow viewing another user's agent" do
    other_runtime_instance = create(:runtime_instance, workspace: create(:user).default_workspace)

    get agent_path(other_runtime_instance)

    expect(response).to have_http_status(:not_found)
  end
end
