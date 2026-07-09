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
end
