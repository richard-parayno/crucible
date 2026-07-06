# frozen_string_literal: true

FactoryBot.define do
  factory :runtime_definition do
    kind { "custom" }
    name { "Custom Runtime" }
    description { "Runtime for specs" }
    container_image { "alpine:latest" }
    default_command { "echo hello" }
    default_env { {"RUNTIME_ENV" => "test"} }
    config_schema { {} }
    active { true }
  end
end
