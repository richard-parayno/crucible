# frozen_string_literal: true

require "rails_helper"

RSpec.describe EnvironmentVariableResolver do
  describe ".call" do
    it "resolves env sources in override order" do
      runtime_definition = create(
        :runtime_definition,
        default_env: {
          "DEFAULT_ONLY" => "definition",
          "SHARED" => "definition",
          "SYSTEM_OVERRIDE" => "definition",
          "RUNTIME_OVERRIDE" => "definition",
          "INSTANCE_OVERRIDE" => "definition",
          "CONFIG_OVERRIDE" => "definition"
        }
      )
      runtime_instance = create(
        :runtime_instance,
        runtime_definition:,
        env: {
          "INSTANCE_ONLY" => "instance",
          "INSTANCE_OVERRIDE" => "instance",
          "CONFIG_OVERRIDE" => "instance"
        },
        config: {
          "env" => {
            "CONFIG_ONLY" => "config",
            "CONFIG_OVERRIDE" => "config"
          }
        }
      )

      create(:environment_variable, scope: "system", key: "SYSTEM_ONLY", value: "system")
      create(:environment_variable, scope: "system", key: "SYSTEM_OVERRIDE", value: "system")
      create(:environment_variable, scope: "system", key: "RUNTIME_OVERRIDE", value: "system")
      create(:environment_variable, scope: "system", key: "INSTANCE_OVERRIDE", value: "system")
      create(:environment_variable, scope: "system", key: "CONFIG_OVERRIDE", value: "system")
      create(:environment_variable, :runtime_instance_scope, runtime_instance:, key: "RUNTIME_ONLY", value: "runtime")
      create(:environment_variable, :runtime_instance_scope, runtime_instance:, key: "RUNTIME_OVERRIDE", value: "runtime")
      create(:environment_variable, :runtime_instance_scope, runtime_instance:, key: "INSTANCE_OVERRIDE", value: "runtime")
      create(:environment_variable, :runtime_instance_scope, runtime_instance:, key: "CONFIG_OVERRIDE", value: "runtime")

      env = described_class.call(runtime_instance)

      expect(env).to include(
        "DEFAULT_ONLY" => "definition",
        "SYSTEM_ONLY" => "system",
        "SYSTEM_OVERRIDE" => "system",
        "RUNTIME_ONLY" => "runtime",
        "RUNTIME_OVERRIDE" => "runtime",
        "INSTANCE_ONLY" => "instance",
        "INSTANCE_OVERRIDE" => "instance",
        "CONFIG_ONLY" => "config",
        "CONFIG_OVERRIDE" => "config"
      )
    end

    it "ignores disabled variables" do
      runtime_instance = create(:runtime_instance)
      create(:environment_variable, scope: "system", key: "DISABLED_SYSTEM", value: "system", enabled: false)
      create(:environment_variable, :runtime_instance_scope, runtime_instance:, key: "DISABLED_RUNTIME", value: "runtime", enabled: false)

      expect(described_class.call(runtime_instance)).not_to include("DISABLED_SYSTEM", "DISABLED_RUNTIME")
    end

    it "does not include variables for other runtime instances" do
      runtime_instance = create(:runtime_instance)
      other_runtime_instance = create(:runtime_instance, runtime_definition: runtime_instance.runtime_definition)
      create(:environment_variable, :runtime_instance_scope, runtime_instance: other_runtime_instance, key: "OTHER_RUNTIME", value: "runtime")

      expect(described_class.call(runtime_instance)).not_to include("OTHER_RUNTIME")
    end
  end
end
