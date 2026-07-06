# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlacementDrivers::LocalContainer do
  FakeStatus = Struct.new(:success?)
  FakeResult = Struct.new(:stdout, :stderr, :status) do
    def success?
      status.success?
    end
  end

  class FakeCommandRunner
    attr_reader :calls

    def initialize(results)
      @results = results
      @calls = []
    end

    def call(*argv)
      @calls << argv
      @results.shift || FakeResult.new("", "", FakeStatus.new(true))
    end
  end

  def result(stdout: "", stderr: "", success: true)
    FakeResult.new(stdout, stderr, FakeStatus.new(success))
  end

  describe "#start" do
    it "starts a local container and records lifecycle events" do
      runtime_instance = create(:runtime_instance)
      adapter_spec = RuntimeAdapters::AdapterSpec.new(
        image: "alpine:latest",
        command: "echo ready",
        env: {"A" => "1"},
        labels: {"crucible.runtime_instance_id" => runtime_instance.id.to_s},
        workdir: "/workspace"
      )
      runner = FakeCommandRunner.new([
        result,
        result(stdout: "container-123\n"),
        result(stdout: "ready\n")
      ])

      described_class.new(command_runner: runner).start(runtime_instance, adapter_spec)

      expect(runtime_instance.reload.status).to eq("running")
      expect(runtime_instance.external_id).to eq("container-123")
      expect(runner.calls.second).to include("run", "--detach", "--name")
      expect(runtime_instance.runtime_events.pluck(:message)).to include(
        "Started docker container crucible-#{runtime_instance.id}-custom",
        "ready"
      )
    end
  end

  describe "#status" do
    it "maps a running container state through the adapter health check" do
      runtime_instance = create(:runtime_instance, container_name: "runtime")
      runner = FakeCommandRunner.new([result(stdout: "running\n")])
      adapter = RuntimeAdapters::Custom.new

      expect(described_class.new(command_runner: runner).status(runtime_instance, adapter)).to eq(["running", nil])
    end
  end
end
