# frozen_string_literal: true

require "rails_helper"
require "tempfile"

RSpec.describe HostCapabilities do
  FakeStatus = Struct.new(:success?)
  FakeResult = Struct.new(:stdout, :stderr, :status) do
    def success?
      status.success?
    end
  end

  class FakeCapabilityRunner
    attr_reader :calls

    def initialize(results)
      @results = results
      @calls = []
    end

    def call(*argv)
      @calls << argv
      @results.fetch(argv) { FakeResult.new("", "unexpected command: #{argv.inspect}", FakeStatus.new(false)) }
    end
  end

  def result(stdout: "", stderr: "", success: true)
    FakeResult.new(stdout, stderr, FakeStatus.new(success))
  end

  def detector(results:, lookup:, meminfo:)
    meminfo_file = Tempfile.new("meminfo")
    meminfo_file.write(meminfo)
    meminfo_file.close

    described_class.new(
      command_runner: FakeCapabilityRunner.new(results),
      command_lookup: ->(command) { lookup.fetch(command, "") },
      disk_path: "/workspace",
      meminfo_path: meminfo_file.path
    )
  end

  it "detects docker, compose, rootless docker, tailscale, disk, memory, and agent binaries" do
    capabilities = detector(
      lookup: {
        "docker" => "/usr/bin/docker",
        "tailscale" => "/usr/bin/tailscale",
        "codex" => "/home/app/bin/codex",
        "claude" => "",
        "opencode" => "/home/app/bin/opencode",
        "openclaw" => "",
        "hermes-agent" => "/usr/local/bin/hermes-agent"
      },
      meminfo: "MemTotal:       16384000 kB\nMemAvailable:    8192000 kB\n",
      results: {
        ["docker", "compose", "version", "--short"] => result(stdout: "2.35.1\n"),
        ["docker", "info", "--format", "{{json .SecurityOptions}}"] => result(stdout: "[\"name=rootless\"]\n"),
        ["df", "-Pk", "/workspace"] => result(stdout: "Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/root 1000 250 750 25% /\n")
      }
    ).call

    expect(capabilities.dig(:container, :docker)).to include(status: "supported", supported: true, path: "/usr/bin/docker")
    expect(capabilities.dig(:container, :docker_compose)).to include(status: "supported", path: "2.35.1")
    expect(capabilities.dig(:container, :rootless_docker)).to include(status: "supported", supported: true)
    expect(capabilities.dig(:networking, :tailscale)).to include(status: "supported", path: "/usr/bin/tailscale")
    expect(capabilities.dig(:host, :disk)).to include(status: "detected", total_bytes: 1_024_000, available_bytes: 768_000)
    expect(capabilities.dig(:host, :memory)).to include(status: "detected", total_bytes: 16_777_216_000, available_bytes: 8_388_608_000)
    expect(capabilities.dig(:agent_binaries, "codex")).to include(status: "supported", path: "/home/app/bin/codex")
    expect(capabilities.dig(:agent_binaries, "claude")).to include(status: "unsupported", supported: false, path: nil)
    expect(capabilities.dig(:agent_binaries, "opencode")).to include(status: "supported", path: "/home/app/bin/opencode")
    expect(capabilities.dig(:agent_binaries, "openclaw")).to include(status: "unsupported", supported: false, path: nil)
    expect(capabilities.dig(:agent_binaries, "hermes")).to include(status: "supported", path: "/usr/local/bin/hermes-agent")
  end

  it "does not run compose or rootless probes when docker is missing" do
    runner = FakeCapabilityRunner.new(
      ["df", "-Pk", "/workspace"] => result(stdout: "Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/root 1000 250 750 25% /\n")
    )
    meminfo_file = Tempfile.new("meminfo")
    meminfo_file.write("MemTotal: 1024 kB\n")
    meminfo_file.close

    capabilities = described_class.new(
      command_runner: runner,
      command_lookup: ->(_command) { "" },
      disk_path: "/workspace",
      meminfo_path: meminfo_file.path
    ).call

    expect(capabilities.dig(:container, :docker)).to include(status: "unsupported")
    expect(capabilities.dig(:container, :docker_compose)).to include(status: "unsupported")
    expect(capabilities.dig(:container, :rootless_docker)).to include(status: "unknown")
    expect(runner.calls).to eq([["df", "-Pk", "/workspace"]])
  end
end
