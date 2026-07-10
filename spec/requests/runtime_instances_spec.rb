# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Runtime instances", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user:) }
  before { sign_in_as(user) }

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
