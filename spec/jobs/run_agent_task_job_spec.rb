# frozen_string_literal: true

require "rails_helper"

RSpec.describe RunAgentTaskJob, type: :job do
  def command_result(stdout: "", stderr: "", success: true, exitstatus: 0)
    status = double("status", success?: success, exitstatus:)

    CommandRunner::Result.new(stdout:, stderr:, status:)
  end

  it "executes an agent run through the placement driver" do
    agent_run = create(:agent_run, command: "echo ready")
    driver = double("driver")

    allow(PlacementDrivers).to receive(:for).with("docker_compose").and_return(driver)
    allow(driver).to receive(:exec).with(agent_run.runtime_instance, "echo ready").and_return(command_result(stdout: "ready\n"))

    described_class.perform_now(agent_run)

    expect(agent_run.reload).to have_attributes(
      status: "succeeded",
      exit_code: 0,
      output: "ready\n"
    )
  end

  it "marks the run failed when the command exits non-zero" do
    agent_run = create(:agent_run, command: "false")
    driver = double("driver")

    allow(PlacementDrivers).to receive(:for).with("docker_compose").and_return(driver)
    allow(driver).to receive(:exec).with(agent_run.runtime_instance, "false").and_return(
      command_result(stderr: "failed\n", success: false, exitstatus: 2)
    )

    described_class.perform_now(agent_run)

    expect(agent_run.reload).to have_attributes(
      status: "failed",
      exit_code: 2,
      output: "failed\n",
      status_message: "Command exited with status 2."
    )
  end
end
