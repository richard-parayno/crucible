# frozen_string_literal: true

class HostAgentProcessInventory
  ProcessRow = Data.define(
    :pid,
    :user,
    :command,
    :comm,
    :executable,
    :cwd,
    :started_at,
    :age_seconds,
    :agent_kind,
    :agent_name,
    :importable
  )

  PS_ARGS = ["ps", "-eo", "pid=,user=,lstart=,comm=,args="].freeze

  def initialize(command_runner: CommandRunner.new, proc_root: Pathname.new("/proc"), clock: -> { Time.current })
    @command_runner = command_runner
    @proc_root = proc_root
    @clock = clock
  end

  def call
    result = command_runner.call(*PS_ARGS)
    return [] unless result.success?

    result.stdout.lines.filter_map { |line| process_row(line) }
  end

  private

  attr_reader :command_runner, :proc_root, :clock

  def process_row(line)
    parsed = parse_ps_line(line)
    return unless parsed

    catalog_entry = catalog_entry_for(parsed.fetch(:comm), parsed.fetch(:command))
    return unless catalog_entry

    started_at = parse_time(parsed.fetch(:lstart))

    ProcessRow.new(
      pid: parsed.fetch(:pid),
      user: parsed.fetch(:user),
      command: parsed.fetch(:command),
      comm: parsed.fetch(:comm),
      executable: readlink(parsed.fetch(:pid), "exe"),
      cwd: readlink(parsed.fetch(:pid), "cwd"),
      started_at:,
      age_seconds: age_seconds(started_at),
      agent_kind: catalog_entry.fetch(:kind),
      agent_name: catalog_entry.fetch(:name),
      importable: RuntimeDefinition.active.exists?(kind: catalog_entry.fetch(:kind))
    )
  end

  def parse_ps_line(line)
    line = line.chomp
    match = line.match(/\A\s*(?<pid>\d+)\s+(?<user>\S+)\s+(?<lstart>.{24})\s+(?<comm>\S+)(?:\s+(?<command>.*))?\z/)
    return unless match

    {
      pid: match[:pid].to_i,
      user: match[:user],
      lstart: match[:lstart],
      comm: match[:comm],
      command: match[:command].presence || match[:comm]
    }
  end

  def catalog_entry_for(comm, command)
    executable_name = File.basename(command.to_s.split.first.to_s)

    AgentCatalog.detectable_runtimes.find do |entry|
      names = Array(entry.fetch(:process_names)) + [entry[:binary]]
      names.compact.any? { |name| name == comm || name == executable_name }
    end
  end

  def readlink(pid, name)
    File.readlink(proc_root.join(pid.to_s, name))
  rescue Errno::ENOENT, Errno::EACCES, Errno::EINVAL
    nil
  end

  def parse_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def age_seconds(started_at)
    return unless started_at

    [clock.call - started_at, 0].max.to_i
  end
end
