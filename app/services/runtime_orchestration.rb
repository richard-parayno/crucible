# frozen_string_literal: true

module RuntimeOrchestration
  class CommandFailed < StandardError; end

  class Supervisor
    def start(runtime_instance)
      runtime_instance.start!
      runtime_instance.runtime_events.create!(level: "info", message: "Starting local runtime.", occurred_at: Time.current)

      adapter = RuntimeAdapters.for(runtime_instance.runtime_definition.kind)
      adapter_spec = adapter.spec_for(runtime_instance)
      driver = PlacementDrivers.for(runtime_instance.placement_kind)

      driver.start(runtime_instance, adapter_spec)
      broadcast_instance(runtime_instance)
    rescue StandardError => e
      runtime_instance.failed!(e.message)
      runtime_instance.runtime_events.create!(level: "error", message: e.message, occurred_at: Time.current)
      broadcast_instance(runtime_instance)
      raise
    end

    def stop(runtime_instance)
      driver = PlacementDrivers.for(runtime_instance.placement_kind)
      driver.stop(runtime_instance)
      broadcast_instance(runtime_instance)
    rescue StandardError => e
      runtime_instance.failed!(e.message)
      runtime_instance.runtime_events.create!(level: "error", message: e.message, occurred_at: Time.current)
      broadcast_instance(runtime_instance)
      raise
    end

    def health_check(runtime_instance)
      adapter = RuntimeAdapters.for(runtime_instance.runtime_definition.kind)
      driver = PlacementDrivers.for(runtime_instance.placement_kind)
      status, message = driver.status(runtime_instance, adapter)

      case status
      when "running"
        runtime_instance.update!(status: "running", last_heartbeat_at: Time.current, status_message: nil)
      when "stopped"
        runtime_instance.stopped!(message)
      when "failed"
        runtime_instance.failed!(message)
      else
        runtime_instance.unhealthy!(message)
      end

      broadcast_instance(runtime_instance)
    end

    private

    def broadcast_instance(runtime_instance)
      RuntimeInstancesChannel.broadcast_to(
        runtime_instance.workspace,
        {
          type: "runtime_instance",
          instance: RuntimeInstanceSerializer.instance(runtime_instance)
        }
      )
    end
  end
end
