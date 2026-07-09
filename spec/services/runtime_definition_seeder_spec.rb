# frozen_string_literal: true

require "rails_helper"

RSpec.describe RuntimeDefinitionSeeder do
  describe ".call" do
    it "seeds catalog runtime definitions including Codex" do
      described_class.call

      expect(RuntimeDefinition.order(:kind).pluck(:kind)).to contain_exactly("codex", "custom", "hermes", "openclaw")
      expect(RuntimeDefinition.find_by!(kind: "codex").config_schema.fetch("templates").pluck("mode")).to contain_exactly("managed_image", "host_binary")
    end

    it "updates existing runtime definitions from the catalog" do
      create(:runtime_definition, kind: "codex", name: "Old Codex", container_image: "old", default_command: "old")

      described_class.call

      codex = RuntimeDefinition.find_by!(kind: "codex")
      expect(codex.name).to eq("Codex")
      expect(codex.container_image).to eq("node:24-alpine")
    end
  end
end
