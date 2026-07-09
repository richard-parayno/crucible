# frozen_string_literal: true

class RuntimeInstanceBroadcaster
  def self.call(runtime_instance)
    runtime_instance.reload

    RuntimeInstancesChannel.broadcast_to(
      runtime_instance.workspace,
      {
        type: "runtime_instance",
        instance: RuntimeInstanceSerializer.instance(runtime_instance)
      }
    )
  end
end
