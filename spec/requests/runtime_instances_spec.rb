# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Runtime instances", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user:) }
  let(:runtime_definition) { create(:runtime_definition) }

  before do
    sign_in_as(user)
    ActiveJob::Base.queue_adapter = :test
  end

  it "creates a docker compose runtime instance" do
    post workspace_runtime_instances_path(workspace), params: {
      runtime_definition_id: runtime_definition.id,
      name: "Local custom",
      config: {"command" => "echo ready"}.to_json,
      env: {"TOKEN" => "redacted"}.to_json
    }

    runtime_instance = workspace.runtime_instances.first
    expect(response).to redirect_to(workspace_path(workspace, runtime_instance_id: runtime_instance.id))
    expect(runtime_instance).to have_attributes(
      name: "Local custom",
      placement_kind: "docker_compose",
      container_runtime: "docker",
      status: "pending"
    )
    expect(runtime_instance.config).to eq("command" => "echo ready")
  end

  it "queues lifecycle jobs for a runtime owned by the current user" do
    runtime_instance = create(:runtime_instance, workspace:)

    expect do
      post start_workspace_runtime_instance_path(workspace, runtime_instance)
    end.to have_enqueued_job(StartRuntimeInstanceJob).with(runtime_instance)

    expect do
      post stop_workspace_runtime_instance_path(workspace, runtime_instance)
    end.to have_enqueued_job(StopRuntimeInstanceJob).with(runtime_instance)
  end
end
