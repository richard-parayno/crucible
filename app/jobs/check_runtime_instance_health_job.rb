# frozen_string_literal: true

class CheckRuntimeInstanceHealthJob < ApplicationJob
  queue_as :default

  def perform(runtime_instance)
    RuntimeOrchestration::Supervisor.new.health_check(runtime_instance)
  end
end
