# frozen_string_literal: true

require "rails_helper"

RSpec.describe RuntimeDefinition, type: :model do
  describe "kind validation" do
    it "allows every managed and observed MVP runtime kind" do
      expect(described_class::KINDS).to eq(%w[codex claude opencode openclaw hermes custom])

      described_class::KINDS.each do |kind|
        runtime_definition = build(:runtime_definition, kind:)

        expect(runtime_definition).to be_valid
      end
    end
  end

  describe ".supported_for_add_agent" do
    it "returns active supported definitions in catalog order and hides custom" do
      RuntimeDefinitionSeeder.call
      RuntimeDefinition.find_by!(kind: "opencode").update!(active: false)

      expect(described_class.supported_for_add_agent.pluck(:kind)).to eq(%w[codex claude hermes openclaw])
    end
  end
end
