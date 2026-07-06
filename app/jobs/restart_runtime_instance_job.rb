# frozen_string_literal: true

class RestartRuntimeInstanceJob < ApplicationJob
  queue_as :default

  def perform(runtime_instance)
    supervisor = RuntimeOrchestration::Supervisor.new
    supervisor.stop(runtime_instance) if runtime_instance.status.in?(%w[running unhealthy])
    supervisor.start(runtime_instance)
  end
end
