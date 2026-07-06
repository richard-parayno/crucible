# frozen_string_literal: true

class StartRuntimeInstanceJob < ApplicationJob
  queue_as :default

  def perform(runtime_instance)
    RuntimeOrchestration::Supervisor.new.start(runtime_instance)
  end
end
