# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentCatalog do
  describe ".runtime_definitions" do
    it "includes serializable runtime definitions for the MVP agents" do
      definitions = described_class.runtime_definitions

      expect(definitions.pluck(:kind)).to eq(%w[codex claude opencode openclaw hermes custom])
      expect(definitions).to all(include(:kind, :name, :description, :container_image, :default_command, :default_env, :config_schema))
      expect(definitions.map { |definition| definition.fetch(:config_schema).fetch("templates") }).to all(be_present)
    end

    it "exposes managed image, host binary, and custom template metadata where applicable" do
      entries = described_class.entries.index_by { |entry| entry.fetch(:kind) }

      expect(entries.fetch("codex").fetch(:templates).pluck(:mode)).to contain_exactly("managed_image", "host_binary")
      expect(entries.fetch("claude").fetch(:templates).pluck(:mode)).to contain_exactly("managed_image", "host_binary")
      expect(entries.fetch("opencode").fetch(:templates).pluck(:mode)).to contain_exactly("managed_image", "host_binary")
      expect(entries.fetch("openclaw").fetch(:templates).pluck(:mode)).to contain_exactly("managed_image", "host_binary")
      expect(entries.fetch("hermes").fetch(:templates).pluck(:mode)).to contain_exactly("managed_image", "host_binary")
      expect(entries.fetch("custom").fetch(:templates).pluck(:mode)).to contain_exactly("custom")
    end

    it "includes expected config mount paths for every managed runtime template" do
      templates_by_kind = described_class.entries.index_by { |entry| entry.fetch(:kind) }.transform_values do |entry|
        entry.fetch(:templates)
      end

      expect(templates_by_kind.fetch("codex")).to all(include(config_mount_path: "/root/.codex"))
      expect(templates_by_kind.fetch("claude")).to all(include(config_mount_path: "/root/.claude"))
      expect(templates_by_kind.fetch("opencode")).to all(include(config_mount_path: "/root/.config/opencode"))
      expect(templates_by_kind.fetch("openclaw")).to all(include(config_mount_path: "/root/.openclaw"))
      expect(templates_by_kind.fetch("hermes")).to all(include(config_mount_path: "/root/.config/hermes-agent"))
      expect(templates_by_kind.fetch("custom")).to all(include(config_mount_path: "/root/.config/crucible-agent"))
    end
  end

  describe ".host_binary_templates" do
    it "lists binaries that host capability detection should probe" do
      expect(described_class.host_binary_templates).to contain_exactly(
        {kind: "codex", name: "Codex", binary: "codex"},
        {kind: "claude", name: "Claude Code", binary: "claude"},
        {kind: "opencode", name: "OpenCode", binary: "opencode"},
        {kind: "openclaw", name: "OpenClaw", binary: "openclaw"},
        {kind: "hermes", name: "Hermes Agent", binary: "hermes-agent"}
      )
    end
  end

  describe ".detectable_runtimes" do
    it "normalizes binary and process-name metadata for known agents" do
      expect(described_class.detectable_runtimes).to include(
        hash_including(kind: "codex", name: "Codex", binary: "codex", process_names: ["codex"]),
        hash_including(kind: "claude", name: "Claude Code", binary: "claude", process_names: ["claude"]),
        hash_including(kind: "opencode", name: "OpenCode", binary: "opencode", process_names: ["opencode"]),
        hash_including(kind: "openclaw", name: "OpenClaw", binary: "openclaw", process_names: ["openclaw"]),
        hash_including(kind: "hermes", name: "Hermes Agent", binary: "hermes-agent", process_names: ["hermes-agent", "hermes"])
      )
    end
  end
end
