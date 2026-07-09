# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlacementDrivers::DockerCompose do
  ComposeFakeStatus = Struct.new(:success?)
  ComposeFakeResult = Struct.new(:stdout, :stderr, :status) do
    def success?
      status.success?
    end
  end

  class ComposeFakeCommandRunner
    attr_reader :calls

    def initialize(results)
      @results = results
      @calls = []
    end

    def call(*argv)
      @calls << argv
      @results.shift || ComposeFakeResult.new("", "", ComposeFakeStatus.new(true))
    end
  end

  let(:root) { Rails.root.join("tmp", "docker-compose-driver-spec") }
  let(:project_writer) { ComposeProjectWriter.new(root:) }

  before { FileUtils.rm_rf(root) }
  after { FileUtils.rm_rf(root) }

  def result(stdout: "", stderr: "", success: true)
    ComposeFakeResult.new(stdout, stderr, ComposeFakeStatus.new(success))
  end

  def adapter_spec(runtime_instance, env: {"API_TOKEN" => "super secret"})
    RuntimeAdapters::AdapterSpec.new(
      image: "alpine:latest",
      command: "echo ready",
      env:,
      labels: {"crucible.runtime_instance_id" => runtime_instance.id.to_s},
      workdir: "/workspace"
    )
  end

  def compose_prefix(project)
    [
      "docker",
      "compose",
      "-p",
      project.project_name,
      "-f",
      project.compose_path.to_s,
      "--env-file",
      project.env_path.to_s
    ]
  end

  describe "#start" do
    it "writes the compose project, starts the service, and records sanitized events" do
      runtime_instance = create(:runtime_instance, placement_kind: "docker_compose", env: {"API_TOKEN" => "super secret"})
      runner = ComposeFakeCommandRunner.new([
        result,
        result,
        result(stdout: "agent | ready\nagent | token=super secret\n")
      ])

      described_class.new(command_runner: runner, project_writer:).start(runtime_instance, adapter_spec(runtime_instance))

      project = project_writer.project_for(runtime_instance)
      expect(runtime_instance.reload.status).to eq("running")
      expect(runtime_instance.external_id).to eq(project.project_name)
      expect(runtime_instance.container_name).to eq("agent")
      expect(runner.calls).to eq([
        [*compose_prefix(project), "down", "--remove-orphans"],
        [*compose_prefix(project), "up", "--detach", "agent"],
        [*compose_prefix(project), "logs", "--tail", "100", "agent"]
      ])
      expect(runtime_instance.runtime_events.pluck(:message)).to include(
        "Started docker compose project #{project.project_name} service agent.",
        "agent | ready",
        "agent | token=[FILTERED]"
      )
      expect(runtime_instance.runtime_events.pluck(:message).join("\n")).not_to include("super secret")
      expect(project.compose_path.read).not_to include("super secret")
    end
  end

  describe "#stop" do
    it "stops the compose service and records lifecycle events" do
      runtime_instance = create(:runtime_instance, placement_kind: "docker_compose")
      project = project_writer.write(runtime_instance, adapter_spec(runtime_instance))
      runner = ComposeFakeCommandRunner.new([result])

      described_class.new(command_runner: runner, project_writer:).stop(runtime_instance)

      expect(runtime_instance.reload.status).to eq("stopped")
      expect(runner.calls).to eq([[*compose_prefix(project), "stop", "agent"]])
      expect(runtime_instance.runtime_events.pluck(:message)).to include(
        "Stopped docker compose project #{project.project_name} service agent."
      )
    end
  end

  describe "#restart" do
    it "restarts the compose service and captures recent logs" do
      runtime_instance = create(:runtime_instance, placement_kind: "docker_compose", status: "running")
      project = project_writer.write(runtime_instance, adapter_spec(runtime_instance))
      runner = ComposeFakeCommandRunner.new([
        result,
        result(stdout: "agent | restarted\n")
      ])

      described_class.new(command_runner: runner, project_writer:).restart(runtime_instance)

      expect(runtime_instance.reload.status).to eq("running")
      expect(runner.calls).to eq([
        [*compose_prefix(project), "restart", "agent"],
        [*compose_prefix(project), "logs", "--tail", "100", "agent"]
      ])
      expect(runtime_instance.runtime_events.pluck(:message)).to include(
        "Restarted docker compose project #{project.project_name} service agent.",
        "agent | restarted"
      )
    end
  end

  describe "#exec" do
    it "runs a shell command inside the compose agent service without requiring a TTY" do
      runtime_instance = create(:runtime_instance, placement_kind: "docker_compose")
      project = project_writer.write(runtime_instance, adapter_spec(runtime_instance))
      runner = ComposeFakeCommandRunner.new([result(stdout: "ok\n")])

      compose_result = described_class.new(command_runner: runner, project_writer:).exec(runtime_instance, "echo ok")

      expect(compose_result.stdout).to eq("ok\n")
      expect(runner.calls).to eq([
        [*compose_prefix(project), "exec", "-T", "agent", "sh", "-lc", "echo ok"]
      ])
    end
  end

  describe "#status" do
    it "maps compose service state through the adapter health check" do
      runtime_instance = create(:runtime_instance, placement_kind: "docker_compose")
      project = project_writer.write(runtime_instance, adapter_spec(runtime_instance))
      runner = ComposeFakeCommandRunner.new([
        result(stdout: [{"Service" => "agent", "State" => "running"}].to_json)
      ])
      adapter = RuntimeAdapters::Custom.new

      expect(described_class.new(command_runner: runner, project_writer:).status(runtime_instance, adapter)).to eq(["running", nil])
      expect(runner.calls).to eq([[*compose_prefix(project), "ps", "--all", "--format", "json", "agent"]])
    end
  end
end
