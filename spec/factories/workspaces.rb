# frozen_string_literal: true

FactoryBot.define do
  factory :workspace do
    association :user
    name { "Local workspace" }
    description { "Local runtime experiments" }
  end
end
