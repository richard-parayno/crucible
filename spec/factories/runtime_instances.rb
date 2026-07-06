# frozen_string_literal: true

FactoryBot.define do
  factory :runtime_instance do
    association :workspace
    association :runtime_definition
    name { "Spec runtime" }
    status { "pending" }
    placement_kind { "local_container" }
    container_runtime { "docker" }
    env { {} }
    config { {} }
  end
end
