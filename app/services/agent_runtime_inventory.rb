# frozen_string_literal: true

class AgentRuntimeInventory
  def initialize(
    user:,
    path_lookup: ExecutablePathLookup.new,
    process_inventory: HostAgentProcessInventory.new,
    working_directory: Rails.root.to_s
  )
    @user = user
    @path_lookup = path_lookup
    @process_inventory = process_inventory
    @working_directory = working_directory
  end

  def call
    runtimes = detected_runtime_rows + host_process_rows + manual_runtime_rows

    {
      agent_runtimes: runtimes,
      detected_runtimes: detected_runtime_rows,
      host_processes: host_process_rows,
      manual_runtimes: manual_runtime_rows
    }
  end

  private

  attr_reader :user, :path_lookup, :process_inventory, :working_directory

  def detected_runtime_rows
    @detected_runtime_rows ||= AgentCatalog.detectable_runtimes.filter_map do |runtime|
      command = runtime.fetch(:binary)
      next if command.blank?

      executable_path = path_lookup.call(command)
      next if executable_path.blank?

      AgentRuntimeRowSerializer.detected(
        command:,
        name: runtime.fetch(:name),
        kind: runtime.fetch(:kind),
        executable_path:,
        working_directory:
      )
    end
  end

  def host_process_rows
    @host_process_rows ||= process_inventory.call.map do |process|
      AgentRuntimeRowSerializer.host_process(process)
    end
  end

  def manual_runtime_rows
    @manual_runtime_rows ||= scoped_runtime_instances.map do |runtime_instance|
      AgentRuntimeRowSerializer.manual(runtime_instance)
    end
  end

  def scoped_runtime_instances
    RuntimeInstance
      .joins(:workspace)
      .includes(:workspace, :runtime_definition, :agent_runs)
      .where(workspaces: {user_id: user.id})
      .order(created_at: :desc)
  end
end
