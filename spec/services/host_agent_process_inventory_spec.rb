# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe HostAgentProcessInventory do
  ProcessFakeStatus = Struct.new(:success?)
  ProcessFakeResult = Struct.new(:stdout, :stderr, :status) do
    def success?
      status.success?
    end
  end

  class FakeProcessRunner
    def initialize(stdout:, success: true)
      @stdout = stdout
      @success = success
    end

    def call(*argv)
      raise "unexpected argv: #{argv.inspect}" unless argv == HostAgentProcessInventory::PS_ARGS

      ProcessFakeResult.new(@stdout, "", ProcessFakeStatus.new(@success))
    end
  end

  it "captures known agent process metadata from ps and procfs" do
    RuntimeDefinitionSeeder.call
    started_at = Time.zone.local(2026, 7, 10, 1, 0, 0)

    Dir.mktmpdir do |directory|
      proc_root = Pathname.new(directory)
      process_directory = proc_root.join("4242")
      process_directory.mkpath
      File.symlink("/usr/local/bin/codex", process_directory.join("exe"))
      File.symlink("/home/richard/personal-dev/crucible", process_directory.join("cwd"))

      rows = described_class.new(
        command_runner: FakeProcessRunner.new(
          stdout: " 4242 richard #{started_at.strftime("%a %b %e %H:%M:%S %Y")} codex codex --ask\n" \
            " 5151 richard #{started_at.strftime("%a %b %e %H:%M:%S %Y")} ruby rails server\n"
        ),
        proc_root:,
        clock: -> { started_at + 90.seconds }
      ).call

      expect(rows).to contain_exactly(
        have_attributes(
          pid: 4242,
          user: "richard",
          command: "codex --ask",
          comm: "codex",
          executable: "/usr/local/bin/codex",
          cwd: "/home/richard/personal-dev/crucible",
          started_at:,
          age_seconds: 90,
          agent_kind: "codex",
          agent_name: "Codex",
          importable: true
        )
      )
    end
  end

  it "returns an empty inventory when ps fails" do
    rows = described_class.new(
      command_runner: FakeProcessRunner.new(stdout: "", success: false)
    ).call

    expect(rows).to eq([])
  end
end
