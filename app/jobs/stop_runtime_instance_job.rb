# frozen_string_literal: true

class StopRuntimeInstanceJob < ApplicationJob
  queue_as :default

  def perform(runtime_instance)
    RuntimeOrchestration::Supervisor.new.stop(runtime_instance)
  end
end
