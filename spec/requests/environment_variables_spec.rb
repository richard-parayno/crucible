# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Environment variables", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user:) }
  let(:runtime_definition) { create(:runtime_definition) }
  let(:runtime_instance) { create(:runtime_instance, workspace:, runtime_definition:) }

  before do
    sign_in_as(user)
  end

  it "creates system variables from the workspace scope" do
    post workspace_environment_variables_path(workspace), params: {
      key: "GLOBAL_TOKEN",
      value: "system-secret",
      sensitive: "1"
    }

    expect(response).to redirect_to(dashboard_path)
    expect(EnvironmentVariable.system_variables.last).to have_attributes(
      key: "GLOBAL_TOKEN",
      value: "system-secret",
      sensitive: true,
      enabled: true
    )
  end

  it "creates runtime variables for the selected runtime instance" do
    post workspace_runtime_instance_environment_variables_path(workspace, runtime_instance), params: {
      key: "RUNTIME_TOKEN",
      value: "runtime-secret",
      sensitive: "1"
    }

    expect(response).to redirect_to(agent_path(runtime_instance))
    expect(runtime_instance.environment_variables.last).to have_attributes(
      scope: EnvironmentVariable::RUNTIME_INSTANCE_SCOPE,
      key: "RUNTIME_TOKEN",
      value: "runtime-secret",
      sensitive: true
    )
  end

  it "updates, disables, and deletes runtime variables through the runtime scope" do
    environment_variable = create(:environment_variable, :runtime_instance_scope, runtime_instance:, key: "OLD_KEY")

    patch workspace_runtime_instance_environment_variable_path(workspace, runtime_instance, environment_variable), params: {
      key: "NEW_KEY",
      value: "new-value",
      sensitive: "0"
    }

    expect(response).to redirect_to(agent_path(runtime_instance))
    expect(environment_variable.reload).to have_attributes(key: "NEW_KEY", value: "new-value", sensitive: false)

    patch workspace_runtime_instance_environment_variable_path(workspace, runtime_instance, environment_variable), params: {
      enabled: "0"
    }

    expect(environment_variable.reload).not_to be_enabled

    delete workspace_runtime_instance_environment_variable_path(workspace, runtime_instance, environment_variable)

    expect(EnvironmentVariable.exists?(environment_variable.id)).to be(false)
  end

  it "does not overwrite a sensitive value with a blank edit value" do
    environment_variable = create(:environment_variable, :sensitive, key: "PRESERVED_TOKEN", value: "preserved")

    patch workspace_environment_variable_path(workspace, environment_variable), params: {
      key: "PRESERVED_TOKEN",
      value: "",
      sensitive: "1"
    }

    expect(environment_variable.reload.value).to eq("preserved")
  end

  it "does not allow editing another workspace runtime variable" do
    other_workspace = create(:workspace)
    other_runtime_instance = create(:runtime_instance, workspace: other_workspace, runtime_definition:)
    environment_variable = create(:environment_variable, :runtime_instance_scope, runtime_instance: other_runtime_instance)

    patch workspace_runtime_instance_environment_variable_path(workspace, runtime_instance, environment_variable), params: {
      enabled: "0"
    }

    expect(response).to have_http_status(:not_found)
    expect(environment_variable.reload).to be_enabled
  end
end
