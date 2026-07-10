# frozen_string_literal: true

class SystemChecksController < InertiaController
  before_action :sync_runtime_definitions

  def show
    render inertia: {
      runtime_definitions: RuntimeDefinition.active.map { |runtime_definition| RuntimeInstanceSerializer.runtime_definition(runtime_definition) },
      host_capabilities: HostCapabilities.new.call
    }
  end

  private

  def sync_runtime_definitions
    RuntimeDefinitionSeeder.call
  end
end
