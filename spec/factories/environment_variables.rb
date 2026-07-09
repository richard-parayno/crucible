# frozen_string_literal: true

FactoryBot.define do
  factory :environment_variable do
    scope { EnvironmentVariable::SYSTEM_SCOPE }
    key { "SPEC_VARIABLE" }
    value { "spec-value" }
    sensitive { false }
    enabled { true }
    runtime_instance { nil }

    trait :runtime_instance_scope do
      scope { EnvironmentVariable::RUNTIME_INSTANCE_SCOPE }
      association :runtime_instance
    end

    trait :sensitive do
      sensitive { true }
      value { "secret-value" }
    end

    trait :disabled do
      enabled { false }
    end
  end
end
