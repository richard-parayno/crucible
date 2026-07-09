# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentRuns::Executor do
  def command_result(stdout: "", stderr: "", success: true, exitstatus: 0)
    status = double("status", success?: success, exitstatus:)

    CommandRunner::Result.new(stdout:, stderr:, status:)
  end

  def resolver_for(driver)
    double("driver_resolver", for: driver)
  end

  it "runs the command, stores sanitized output, and records lifecycle events" do
    runtime_instance = create(:runtime_instance, env: {"API_TOKEN" => "super secret"})
    agent_run = create(:agent_run, runtime_instance:, command: "echo ready")
    driver = double("driver")

    allow(driver).to receive(:exec).with(runtime_instance, "echo ready").and_return(
      command_result(stdout: "ready\nsecret=super secret\n")
    )

    described_class.new(driver_resolver: resolver_for(driver)).call(agent_run)

    expect(agent_run.reload).to have_attributes(
      status: "succeeded",
      exit_code: 0,
      output: "ready\nsecret=[FILTERED]\n",
      status_message: "Command completed successfully."
    )
    expect(agent_run.started_at).to be_present
    expect(agent_run.finished_at).to be_present
    expect(runtime_instance.runtime_events.pluck(:message)).to include(
      "Agent run started.",
      "ready",
      "secret=[FILTERED]",
      "Agent run completed successfully."
    )
    expect(runtime_instance.runtime_events.pluck(:message).join("\n")).not_to include("super secret")
  end

  it "marks the run failed and records stderr when the command fails" do
    runtime_instance = create(:runtime_instance)
    agent_run = create(:agent_run, runtime_instance:, command: "false")
    driver = double("driver")

    allow(driver).to receive(:exec).with(runtime_instance, "false").and_return(
      command_result(stderr: "boom\n", success: false, exitstatus: 7)
    )

    described_class.new(driver_resolver: resolver_for(driver)).call(agent_run)

    expect(agent_run.reload).to have_attributes(
      status: "failed",
      exit_code: 7,
      output: "boom\n",
      status_message: "Command exited with status 7."
    )
    expect(runtime_instance.runtime_events.pluck(:level, :message)).to include(
      ["error", "boom"],
      ["error", "Command exited with status 7."]
    )
  end

  it "marks the run failed when the placement driver cannot execute commands" do
    agent_run = create(:agent_run)
    driver = double("driver without exec")

    expect do
      described_class.new(driver_resolver: resolver_for(driver)).call(agent_run)
    end.to raise_error(RuntimeOrchestration::CommandFailed)

    expect(agent_run.reload).to have_attributes(
      status: "failed",
      status_message: "Placement driver docker_compose does not support command execution."
    )
  end
end
