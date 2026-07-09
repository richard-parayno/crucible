# frozen_string_literal: true

require "shellwords"

class HostCapabilities
  def initialize(
    command_runner: CommandRunner.new,
    command_lookup: nil,
    disk_path: Rails.root,
    meminfo_path: "/proc/meminfo"
  )
    @command_runner = command_runner
    @command_lookup = command_lookup || method(:default_command_lookup)
    @disk_path = disk_path
    @meminfo_path = meminfo_path
  end

  def call
    {
      container: {
        docker: docker_capability,
        docker_compose: docker_compose_capability,
        rootless_docker: rootless_docker_capability
      },
      networking: {
        tailscale: executable_capability("tailscale")
      },
      host: {
        disk: disk_capability,
        memory: memory_capability
      },
      agent_binaries: agent_binary_capabilities
    }
  end

  private

  attr_reader :command_runner, :command_lookup, :disk_path, :meminfo_path

  def docker_capability
    @docker_capability ||= executable_capability("docker")
  end

  def docker_compose_capability
    return unsupported("Docker CLI is missing") unless docker_capability.fetch(:supported)

    result = command_runner.call("docker", "compose", "version", "--short")
    return supported(result.stdout.strip.presence || "docker compose", "Docker Compose plugin is available") if result.success?

    unsupported("Docker Compose plugin is unavailable: #{clean_error(result)}")
  end

  def rootless_docker_capability
    return unknown("Docker CLI is missing") unless docker_capability.fetch(:supported)

    result = command_runner.call("docker", "info", "--format", "{{json .SecurityOptions}}")
    return unknown("Docker rootless status could not be detected: #{clean_error(result)}") unless result.success?

    security_options = result.stdout.to_s.downcase
    return supported(nil, "Docker reports rootless security options") if security_options.include?("rootless")

    unsupported("Docker does not report rootless security options")
  end

  def disk_capability
    result = command_runner.call("df", "-Pk", disk_path.to_s)
    return unknown("Disk capacity could not be detected: #{clean_error(result)}") unless result.success?

    parse_disk(result.stdout)
  end

  def memory_capability
    return unknown("Memory details are unavailable") unless File.readable?(meminfo_path)

    meminfo = File.read(meminfo_path)
    total_kb = meminfo[/^MemTotal:\s+(\d+)\s+kB$/i, 1]
    available_kb = meminfo[/^MemAvailable:\s+(\d+)\s+kB$/i, 1]
    return unknown("Memory details are unavailable") unless total_kb

    {
      status: "detected",
      supported: true,
      total_bytes: total_kb.to_i * 1024,
      available_bytes: available_kb&.to_i&.*(1024),
      reason: "Memory capacity detected from procfs"
    }
  rescue Errno::ENOENT, Errno::EACCES
    unknown("Memory details are unavailable")
  end

  def agent_binary_capabilities
    AgentCatalog.host_binary_templates.to_h do |template|
      [template.fetch(:kind), executable_capability(template.fetch(:binary))]
    end
  end

  def executable_capability(command)
    path = command_lookup.call(command).to_s.strip
    return supported(path, "#{command} found at #{path}") if path.present?

    unsupported("#{command} was not found on PATH")
  end

  def default_command_lookup(command)
    escaped = Shellwords.escape(command)
    result = command_runner.call("sh", "-lc", "command -v #{escaped}")
    result.success? ? result.stdout : ""
  end

  def parse_disk(stdout)
    _header, data = stdout.lines.map(&:strip).reject(&:blank?)
    return unknown("Disk capacity output was not recognized") unless data

    parts = data.split(/\s+/)
    return unknown("Disk capacity output was not recognized") unless parts.size >= 6

    {
      status: "detected",
      supported: true,
      path: parts[5],
      total_bytes: parts[1].to_i * 1024,
      used_bytes: parts[2].to_i * 1024,
      available_bytes: parts[3].to_i * 1024,
      capacity: parts[4],
      reason: "Disk capacity detected with df"
    }
  end

  def supported(path, reason)
    {
      status: "supported",
      supported: true,
      path: path,
      reason: reason
    }
  end

  def unsupported(reason)
    {
      status: "unsupported",
      supported: false,
      path: nil,
      reason: reason
    }
  end

  def unknown(reason)
    {
      status: "unknown",
      supported: false,
      path: nil,
      reason: reason
    }
  end

  def clean_error(result)
    result.stderr.to_s.strip.presence || result.stdout.to_s.strip.presence || "no details"
  end
end
