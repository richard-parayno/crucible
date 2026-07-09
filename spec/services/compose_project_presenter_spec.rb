# frozen_string_literal: true

require "rails_helper"

RSpec.describe ComposeProjectPresenter do
  let(:root) { Rails.root.join("tmp", "compose-project-presenter-spec") }
  let(:project_writer) { ComposeProjectWriter.new(root:) }

  describe ".call" do
    it "returns safe compose metadata and argv commands without reading Docker state" do
      runtime_instance = create(
        :runtime_instance,
        placement_kind: "docker_compose",
        env: {"API_TOKEN" => "super secret"}
      )

      metadata = described_class.call(runtime_instance, project_writer:)

      expect(metadata).to include(
        directory_path: root.join(runtime_instance.id.to_s).to_s,
        compose_path: root.join(runtime_instance.id.to_s, "compose.yml").to_s,
        env_path: root.join(runtime_instance.id.to_s, ".env").to_s,
        project_name: "crucible-#{runtime_instance.id}-custom",
        service_name: "agent"
      )
      expect(metadata.fetch(:commands)).to eq(
        up: compose_command(metadata, "up", "--detach", "agent"),
        stop: compose_command(metadata, "stop", "agent"),
        restart: compose_command(metadata, "restart", "agent"),
        logs: compose_command(metadata, "logs", "--tail", "100", "agent"),
        ps: compose_command(metadata, "ps", "--all", "agent"),
        exec_shell: compose_command(metadata, "exec", "agent", "sh")
      )
      expect(metadata.to_s).not_to include("super secret")
    end

    it "does not expose compose metadata for non-compose runtime placements" do
      runtime_instance = create(:runtime_instance, placement_kind: "local_container")

      expect(described_class.call(runtime_instance, project_writer:)).to be_nil
    end
  end

  def compose_command(metadata, *args)
    [
      "docker",
      "compose",
      "-p",
      metadata.fetch(:project_name),
      "-f",
      metadata.fetch(:compose_path),
      "--env-file",
      metadata.fetch(:env_path),
      *args
    ]
  end
end
