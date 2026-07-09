# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentCatalog do
  describe ".runtime_definitions" do
    it "includes serializable runtime definitions for the MVP agents" do
      definitions = described_class.runtime_definitions

      expect(definitions.pluck(:kind)).to eq(%w[codex openclaw hermes custom])
      expect(definitions).to all(include(:kind, :name, :description, :container_image, :default_command, :default_env, :config_schema))
      expect(definitions.map { |definition| definition.fetch(:config_schema).fetch("templates") }).to all(be_present)
    end

    it "exposes managed image, host binary, and custom template metadata where applicable" do
      entries = described_class.entries.index_by { |entry| entry.fetch(:kind) }

      expect(entries.fetch("codex").fetch(:templates).pluck(:mode)).to contain_exactly("managed_image", "host_binary")
      expect(entries.fetch("openclaw").fetch(:templates).pluck(:mode)).to contain_exactly("managed_image", "host_binary")
      expect(entries.fetch("hermes").fetch(:templates).pluck(:mode)).to contain_exactly("managed_image", "host_binary")
      expect(entries.fetch("custom").fetch(:templates).pluck(:mode)).to contain_exactly("custom")
    end
  end

  describe ".host_binary_templates" do
    it "lists binaries that host capability detection should probe" do
      expect(described_class.host_binary_templates).to contain_exactly(
        {kind: "codex", name: "Codex", binary: "codex"},
        {kind: "openclaw", name: "OpenClaw", binary: "openclaw"},
        {kind: "hermes", name: "Hermes Agent", binary: "hermes-agent"}
      )
    end
  end
end
