# frozen_string_literal: true

class AgentRuntimeInventory
  DETECTABLE_RUNTIMES = [
    {command: "codex", name: "Codex", kind: "codex"},
    {command: "claude", name: "Claude Code", kind: "claude"},
    {command: "opencode", name: "OpenCode", kind: "opencode"},
    {command: "openclaw", name: "OpenClaw", kind: "openclaw"},
    {command: "hermes-agent", name: "Hermes Agent", kind: "hermes_agent"}
  ].freeze

  def initialize(user:, path_lookup: ExecutablePathLookup.new, working_directory: Rails.root.to_s)
    @user = user
    @path_lookup = path_lookup
    @working_directory = working_directory
  end

  def call
    runtimes = detected_runtime_rows + manual_runtime_rows

    {
      agent_runtimes: runtimes,
      detected_runtimes: detected_runtime_rows,
      manual_runtimes: manual_runtime_rows
    }
  end

  private

  attr_reader :user, :path_lookup, :working_directory

  def detected_runtime_rows
    @detected_runtime_rows ||= DETECTABLE_RUNTIMES.filter_map do |runtime|
      executable_path = path_lookup.call(runtime.fetch(:command))
      next if executable_path.blank?

      AgentRuntimeRowSerializer.detected(
        command: runtime.fetch(:command),
        name: runtime.fetch(:name),
        kind: runtime.fetch(:kind),
        executable_path:,
        working_directory:
      )
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
