# frozen_string_literal: true

FactoryBot.define do
  factory :agent_run do
    association :runtime_instance
    prompt { "List the workspace files" }
    command { "ls -la" }
    status { "queued" }
  end
end
