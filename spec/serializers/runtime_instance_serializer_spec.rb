# frozen_string_literal: true

require "rails_helper"

RSpec.describe RuntimeInstanceSerializer do
  describe ".runtime_definition" do
    it "serializes template provenance metadata" do
      runtime_definition = create(
        :runtime_definition,
        **AgentCatalog.runtime_definitions.find { |definition| definition.fetch(:kind) == "codex" }
      )

      serialized = described_class.runtime_definition(runtime_definition)

      expect(serialized).to include(
        kind: "codex",
        metadata: include(
          "trust_level" => "official_upstream",
          "verified_managed_install_available" => false,
          "install_sources" => include(hash_including("kind" => "npm", "package" => "@openai/codex")),
          "trusted_urls" => include(hash_including("url" => "https://github.com/openai/codex")),
          "version_pin" => include("field" => "npm_package_version"),
          "verified_artifacts" => include(hash_including("kind" => "integrity", "value" => "npm registry dist.integrity"))
        )
      )
    end
  end

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
