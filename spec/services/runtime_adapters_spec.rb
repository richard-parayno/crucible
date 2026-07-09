# frozen_string_literal: true

require "rails_helper"

RSpec.describe RuntimeAdapters do
  describe ".for" do
    it "returns the adapter for a supported runtime kind" do
      expect(described_class.for("codex")).to be_a(RuntimeAdapters::Codex)
      expect(described_class.for("openclaw")).to be_a(RuntimeAdapters::OpenClaw)
      expect(described_class.for("hermes")).to be_a(RuntimeAdapters::Hermes)
    end

    it "raises for unknown runtime kinds" do
      expect { described_class.for("missing") }.to raise_error(RuntimeAdapters::UnknownAdapter)
    end
  end

  describe RuntimeAdapters::Custom do
    it "builds a container spec from the runtime definition and instance overrides" do
      runtime_definition = build(:runtime_definition, default_env: {"A" => "1"})
      runtime_instance = build(
        :runtime_instance,
        runtime_definition:,
        env: {"B" => "2"},
        config: {"container_image" => "ruby:4", "command" => "ruby -v"}
      )

      spec = described_class.new.spec_for(runtime_instance)

      expect(spec.image).to eq("ruby:4")
      expect(spec.command).to eq("ruby -v")
      expect(spec.env).to eq("A" => "1", "B" => "2")
      expect(spec.labels).to include("crucible.runtime_kind" => "custom")
    end

    it "includes resolved system and runtime environment variables" do
      runtime_instance = create(:runtime_instance, env: {"A" => "instance"})
      create(:environment_variable, scope: "system", key: "A", value: "system")
      create(:environment_variable, :runtime_instance_scope, runtime_instance:, key: "B", value: "runtime")

      spec = described_class.new.spec_for(runtime_instance)

      expect(spec.env).to include("A" => "instance", "B" => "runtime")
    end
  end

  describe RuntimeAdapters::Codex do
    let(:codex_definition_attrs) do
      AgentCatalog.runtime_definitions.find { |definition| definition.fetch(:kind) == "codex" }
    end

    let(:runtime_definition) { create(:runtime_definition, **codex_definition_attrs) }

    it "uses managed image template defaults unless image or command are overridden" do
      runtime_instance = create(
        :runtime_instance,
        runtime_definition:,
        config: {"template_mode" => "managed_image"}
      )

      spec = described_class.new.spec_for(runtime_instance)

      expect(spec.image).to eq("node:24-alpine")
      expect(spec.command).to eq("echo 'Codex managed image template is not configured yet.' && tail -f /dev/null")
      expect(spec.labels).to include(
        "crucible.runtime_kind" => "codex",
        "crucible.template_mode" => "managed_image"
      )
      expect(spec.volumes).to be_empty

      runtime_instance.config = {
        "template_mode" => "managed_image",
        "container_image" => "ghcr.io/example/codex:edge",
        "command" => "codex serve"
      }

      override_spec = described_class.new.spec_for(runtime_instance)

      expect(override_spec.image).to eq("ghcr.io/example/codex:edge")
      expect(override_spec.command).to eq("codex serve")
    end

    it "renders host binary mode through a read-only bind mount" do
      host_binary_path = Rails.root.join("tmp", "runtime-adapters-codex")
      FileUtils.mkdir_p(host_binary_path.dirname)
      host_binary_path.write("#!/bin/sh\nexit 0\n")
      FileUtils.chmod("+x", host_binary_path)

      runtime_instance = create(
        :runtime_instance,
        runtime_definition:,
        config: {
          "template_mode" => "host_binary",
          "host_binary_path" => host_binary_path.to_s,
          "command" => "--help"
        }
      )

      spec = described_class.new.spec_for(runtime_instance)

      expect(spec.image).to eq("node:24-alpine")
      expect(spec.command).to eq("/opt/crucible/host-binaries/codex --help")
      expect(spec.labels).to include(
        "crucible.template_mode" => "host_binary",
        "crucible.host_binary" => "codex",
        "crucible.host_binary_target" => "/opt/crucible/host-binaries/codex"
      )
      expect(spec.volumes).to eq([
        {
          type: "bind",
          source: host_binary_path.to_s,
          target: "/opt/crucible/host-binaries/codex",
          read_only: true
        }
      ])
    ensure
      FileUtils.rm_f(host_binary_path) if host_binary_path
    end

    it "can use a detected catalog binary path for host binary mode" do
      host_binary_path = Rails.root.join("tmp", "runtime-adapters-detected-codex")
      FileUtils.mkdir_p(host_binary_path.dirname)
      host_binary_path.write("#!/bin/sh\nexit 0\n")
      FileUtils.chmod("+x", host_binary_path)
      host_capabilities = instance_double(HostCapabilities, executable_path: host_binary_path.to_s)
      runtime_instance = create(
        :runtime_instance,
        runtime_definition:,
        config: {"template_mode" => "host_binary"}
      )

      spec = described_class.new(host_capabilities:).spec_for(runtime_instance)

      expect(host_capabilities).to have_received(:executable_path).with("codex")
      expect(spec.volumes.first.fetch(:source)).to eq(host_binary_path.to_s)
      expect(spec.command).to eq("/opt/crucible/host-binaries/codex --help && tail -f /dev/null")
    ensure
      FileUtils.rm_f(host_binary_path) if host_binary_path
    end

    it "fails clearly when host binary mode has no viable host binary path" do
      host_capabilities = instance_double(HostCapabilities, executable_path: nil)
      runtime_instance = create(
        :runtime_instance,
        runtime_definition:,
        config: {"template_mode" => "host_binary"}
      )

      expect do
        described_class.new(host_capabilities:).spec_for(runtime_instance)
      end.to raise_error(
        RuntimeAdapters::UnavailableTemplate,
        "Codex host_binary template requires host_binary_path or a codex binary on PATH."
      )
    end

    it "does not allow host binary mode outside docker compose placement" do
      runtime_instance = create(
        :runtime_instance,
        runtime_definition:,
        placement_kind: "local_container",
        config: {"template_mode" => "host_binary"}
      )

      expect do
        described_class.new.spec_for(runtime_instance)
      end.to raise_error(
        RuntimeAdapters::UnavailableTemplate,
        "host_binary template mode requires docker_compose placement so the host binary can be sandboxed by Compose."
      )
    end
  end
end
