# frozen_string_literal: true

require "rails_helper"

RSpec.describe EnvironmentVariable, type: :model do
  describe "validations" do
    it "allows system variables without a runtime instance" do
      environment_variable = build(:environment_variable, scope: "system", runtime_instance: nil)

      expect(environment_variable).to be_valid
    end

    it "allows runtime-scoped variables with a runtime instance" do
      environment_variable = build(:environment_variable, :runtime_instance_scope)

      expect(environment_variable).to be_valid
    end

    it "requires system variables to omit runtime instance" do
      runtime_instance = build(:runtime_instance)
      environment_variable = build(:environment_variable, scope: "system", runtime_instance:)

      expect(environment_variable).not_to be_valid
      expect(environment_variable.errors[:runtime_instance]).to include("must be blank for system variables")
    end

    it "requires runtime variables to include runtime instance" do
      environment_variable = build(:environment_variable, scope: "runtime_instance", runtime_instance: nil)

      expect(environment_variable).not_to be_valid
      expect(environment_variable.errors[:runtime_instance]).to include("must be present for runtime variables")
    end

    it "requires shell-safe keys" do
      environment_variable = build(:environment_variable, key: "bad-key")

      expect(environment_variable).not_to be_valid
      expect(environment_variable.errors[:key]).to be_present
    end

    it "allows empty string values" do
      environment_variable = build(:environment_variable, value: "")

      expect(environment_variable).to be_valid
    end

    it "rejects nil values" do
      environment_variable = build(:environment_variable, value: nil)

      expect(environment_variable).not_to be_valid
      expect(environment_variable.errors[:value]).to include("can't be nil")
    end

    it "requires system keys to be unique" do
      create(:environment_variable, scope: "system", key: "DUPLICATE_KEY")
      environment_variable = build(:environment_variable, scope: "system", key: "DUPLICATE_KEY")

      expect(environment_variable).not_to be_valid
      expect(environment_variable.errors[:key]).to include("has already been taken")
    end

    it "requires runtime keys to be unique per runtime instance" do
      runtime_instance = create(:runtime_instance)
      create(:environment_variable, :runtime_instance_scope, runtime_instance:, key: "DUPLICATE_KEY")
      environment_variable = build(:environment_variable, :runtime_instance_scope, runtime_instance:, key: "DUPLICATE_KEY")

      expect(environment_variable).not_to be_valid
      expect(environment_variable.errors[:key]).to include("has already been taken")
    end

    it "allows the same runtime key on different runtime instances" do
      create(:environment_variable, :runtime_instance_scope, key: "SHARED_KEY")
      environment_variable = build(:environment_variable, :runtime_instance_scope, key: "SHARED_KEY")

      expect(environment_variable).to be_valid
    end
  end

  describe "encryption" do
    it "encrypts values at rest" do
      environment_variable = create(:environment_variable, value: "plaintext-value")

      raw_value = described_class.connection.select_value(<<~SQL.squish)
        SELECT value FROM environment_variables WHERE id = #{environment_variable.id}
      SQL

      expect(raw_value).not_to eq("plaintext-value")
      expect(environment_variable.reload.value).to eq("plaintext-value")
    end
  end

  describe "#safe_attributes" do
    it "returns non-sensitive values" do
      environment_variable = build(:environment_variable, value: "visible")

      expect(environment_variable.safe_attributes).to include(
        key: "SPEC_VARIABLE",
        value: "visible",
        sensitive: false,
        enabled: true
      )
    end

    it "masks sensitive values" do
      environment_variable = build(:environment_variable, :sensitive, value: "hidden")

      expect(environment_variable.safe_attributes).to include(
        value: EnvironmentVariable::MASKED_VALUE,
        value_present: true
      )
    end
  end
end
