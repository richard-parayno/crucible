# frozen_string_literal: true

class RestartRuntimeInstanceJob < ApplicationJob
  queue_as :default

  def perform(runtime_instance)
    RuntimeOrchestration::Supervisor.new.restart(runtime_instance)
  end
end
