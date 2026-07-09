# frozen_string_literal: true

require "rails_helper"

RSpec.describe ComposeProjectWriter do
  let(:root) { Rails.root.join("tmp", "compose-project-writer-spec") }

  before { FileUtils.rm_rf(root) }
  after { FileUtils.rm_rf(root) }

  describe "#write" do
    it "writes a per-runtime compose project without embedding env values in compose.yml" do
      runtime_instance = create(:runtime_instance, placement_kind: "docker_compose")
      adapter_spec = RuntimeAdapters::AdapterSpec.new(
        image: "alpine:latest",
        command: "echo ready",
        env: {
          "API_TOKEN" => "super secret",
          "CRUCIBLE_MESSAGE" => "hello"
        },
        labels: {"crucible.runtime_instance_id" => runtime_instance.id.to_s},
        workdir: "/workspace"
      )

      project = described_class.new(root:).write(runtime_instance, adapter_spec)

      expect(project.directory).to eq(root.join(runtime_instance.id.to_s))
      expect(project.project_name).to eq("crucible-#{runtime_instance.id}-custom")
      expect(project.service_name).to eq("agent")
      expect(project.compose_path.basename.to_s).to eq("compose.yml")
      expect(project.env_path.basename.to_s).to eq(".env")

      compose = YAML.safe_load(project.compose_path.read)
      agent = compose.fetch("services").fetch("agent")

      expect(agent).to include(
        "image" => "alpine:latest",
        "working_dir" => "/workspace",
        "command" => ["sh", "-lc", "echo ready"]
      )
      expect(agent.fetch("environment")).to eq(
        "API_TOKEN" => "${API_TOKEN}",
        "CRUCIBLE_MESSAGE" => "${CRUCIBLE_MESSAGE}"
      )
      expect(agent.fetch("labels")).to eq("crucible.runtime_instance_id" => runtime_instance.id.to_s)
      expect(project.compose_path.read).not_to include("super secret")
      expect(project.env_path.read).to include("API_TOKEN='super secret'")
      expect(project.env_path.read).to include("CRUCIBLE_MESSAGE='hello'")
    end

    it "writes host binary mounts and labels without embedding env values" do
      runtime_definition = create(:runtime_definition, **AgentCatalog.runtime_definitions.find { |definition| definition.fetch(:kind) == "codex" })
      runtime_instance = create(:runtime_instance, runtime_definition:, placement_kind: "docker_compose")
      adapter_spec = RuntimeAdapters::AdapterSpec.new(
        image: "node:24-alpine",
        command: "/opt/crucible/host-binaries/codex --help",
        env: {"API_TOKEN" => "super secret"},
        labels: {
          "crucible.runtime_instance_id" => runtime_instance.id.to_s,
          "crucible.runtime_kind" => "codex",
          "crucible.template_mode" => "host_binary",
          "crucible.host_binary" => "codex",
          "crucible.host_binary_target" => "/opt/crucible/host-binaries/codex"
        },
        workdir: "/",
        volumes: [
          {
            type: "bind",
            source: "/usr/local/bin/codex",
            target: "/opt/crucible/host-binaries/codex",
            read_only: true
          }
        ]
      )

      project = described_class.new(root:).write(runtime_instance, adapter_spec)
      compose = YAML.safe_load(project.compose_path.read)
      agent = compose.fetch("services").fetch("agent")

      expect(agent).to include(
        "image" => "node:24-alpine",
        "working_dir" => "/",
        "command" => ["sh", "-lc", "/opt/crucible/host-binaries/codex --help"]
      )
      expect(agent.fetch("volumes")).to eq([
        {
          "type" => "bind",
          "source" => "/usr/local/bin/codex",
          "target" => "/opt/crucible/host-binaries/codex",
          "read_only" => true
        }
      ])
      expect(agent.fetch("labels")).to include(
        "crucible.runtime_kind" => "codex",
        "crucible.template_mode" => "host_binary",
        "crucible.host_binary_target" => "/opt/crucible/host-binaries/codex"
      )
      expect(agent.fetch("environment")).to eq("API_TOKEN" => "${API_TOKEN}")
      expect(project.compose_path.read).not_to include("super secret")
      expect(project.env_path.read).to include("API_TOKEN='super secret'")
    end
  end
end
