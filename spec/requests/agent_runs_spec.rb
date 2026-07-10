# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AgentRuns", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user:) }
  let(:runtime_instance) { create(:runtime_instance, workspace:) }

  before { sign_in_as(user) }

  it "creates an agent run for an owned runtime instance and queues execution" do
    expect do
      expect do
        post workspace_runtime_instance_agent_runs_path(workspace, runtime_instance), params: {
          prompt: "Check the app",
          command: "bin/rails about"
        }
      end.to have_enqueued_job(RunAgentTaskJob)
    end.to change(AgentRun, :count).by(1)

    agent_run = runtime_instance.agent_runs.sole
    expect(response).to redirect_to(agent_path(runtime_instance))
    expect(agent_run).to have_attributes(
      prompt: "Check the app",
      command: "bin/rails about",
      status: "queued"
    )
  end

  it "falls back to the prompt as the command for simple submissions" do
    post workspace_runtime_instance_agent_runs_path(workspace, runtime_instance), params: {
      prompt: "echo hello"
    }

    expect(runtime_instance.agent_runs.sole.command).to eq("echo hello")
  end

  it "does not enqueue invalid runs" do
    expect do
      expect do
        post workspace_runtime_instance_agent_runs_path(workspace, runtime_instance), params: {
          command: ""
        }
      end.not_to have_enqueued_job(RunAgentTaskJob)
    end.not_to change(AgentRun, :count)

    expect(response).to redirect_to(agent_path(runtime_instance))
  end

  it "does not create runs for another user's runtime instance" do
    other_workspace = create(:workspace)
    other_runtime_instance = create(:runtime_instance, workspace: other_workspace)

    expect do
      post workspace_runtime_instance_agent_runs_path(other_workspace, other_runtime_instance), params: {
        command: "echo nope"
      }
    end.not_to change(AgentRun, :count)

    expect(response).to have_http_status(:not_found)
  end
end
