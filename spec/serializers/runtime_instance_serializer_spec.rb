# frozen_string_literal: true

require "rails_helper"

RSpec.describe RuntimeInstanceSerializer do
  describe ".instance" do
    it "includes safe compose escape-hatch metadata" do
      runtime_instance = create(
        :runtime_instance,
        placement_kind: "docker_compose",
        env: {"API_TOKEN" => "super secret"}
      )

      serialized = described_class.instance(runtime_instance)
      compose_project = serialized.fetch(:compose_project)

      expect(compose_project).to include(
        directory_path: Rails.root.join("storage", "runtimes", runtime_instance.id.to_s).to_s,
        compose_path: Rails.root.join("storage", "runtimes", runtime_instance.id.to_s, "compose.yml").to_s,
        env_path: Rails.root.join("storage", "runtimes", runtime_instance.id.to_s, ".env").to_s,
        project_name: "crucible-#{runtime_instance.id}-custom",
        service_name: "agent"
      )
      expect(compose_project.fetch(:commands).fetch(:up)).to include("up", "--detach", "agent")
      expect(serialized.to_s).not_to include("super secret")
    end
  end
end
