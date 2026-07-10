# frozen_string_literal: true

class SystemChecksController < InertiaController
  before_action :sync_runtime_definitions

  def show
    runtime_inventory = AgentRuntimeInventory.new(user: Current.session.user).call

    render inertia: {
      runtime_definitions: RuntimeDefinition.supported_for_add_agent.map { |runtime_definition| RuntimeInstanceSerializer.runtime_definition(runtime_definition) },
      host_capabilities: HostCapabilities.new.call,
      installed_binaries: runtime_inventory.fetch(:detected_runtimes),
      host_processes: runtime_inventory.fetch(:host_processes),
      managed_runtimes: runtime_inventory.fetch(:manual_runtimes)
    }
  end

  private

  def sync_runtime_definitions
    RuntimeDefinitionSeeder.call
  end
end
