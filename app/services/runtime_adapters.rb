# frozen_string_literal: true

require "shellwords"

module RuntimeAdapters
  HOST_BINARY_COMMAND_PLACEHOLDER = "{{host_binary}}"
  HOST_BINARY_MOUNT_DIR = "/opt/crucible/host-binaries"

  AdapterSpec = Data.define(:image, :command, :env, :labels, :workdir, :volumes) do
    def initialize(image:, command:, env:, labels:, workdir:, volumes: [])
      super
    end
  end

  class UnknownAdapter < StandardError; end
  class UnavailableTemplate < StandardError; end

  def self.for(kind)
    case kind
    when "codex"
      Codex.new
    when "openclaw"
      OpenClaw.new
    when "hermes"
      Hermes.new
    when "custom"
      Custom.new
    else
      raise UnknownAdapter, "Unknown runtime adapter: #{kind}"
    end
  end

  class Base
    def initialize(host_capabilities: HostCapabilities.new)
      @host_capabilities = host_capabilities
    end

    def spec_for(runtime_instance)
      runtime_definition = runtime_instance.runtime_definition
      config = runtime_instance.config || {}
      template = selected_template(runtime_definition, config)

      case template.fetch(:mode)
      when "host_binary"
        host_binary_spec(runtime_instance, template, config)
      else
        managed_image_spec(runtime_instance, template, config)
      end
    end

    def health_status(_runtime_instance, container_state)
      return ["running", nil] if container_state == "running"

      ["unhealthy", "Container state is #{container_state}"]
    end

    private

    attr_reader :host_capabilities

    def managed_image_spec(runtime_instance, template, config)
      runtime_definition = runtime_instance.runtime_definition

      AdapterSpec.new(
        image: config["container_image"].presence || template[:container_image].presence || runtime_definition.container_image,
        command: config["command"].presence || template[:default_command].presence || runtime_definition.default_command,
        env: EnvironmentVariableResolver.call(runtime_instance),
        labels: base_labels(runtime_instance).merge(
          "crucible.template_mode" => template.fetch(:mode)
        ),
        workdir: "/"
      )
    end

    def host_binary_spec(runtime_instance, template, config)
      require_docker_compose_placement!(runtime_instance, template)

      runtime_definition = runtime_instance.runtime_definition
      binary = template.fetch(:binary)
      source_path = host_binary_path!(runtime_definition, template, config)
      target_path = File.join(HOST_BINARY_MOUNT_DIR, File.basename(binary))

      AdapterSpec.new(
        image: config["container_image"].presence || template[:container_image].presence || runtime_definition.container_image,
        command: host_binary_command(template, config, target_path),
        env: EnvironmentVariableResolver.call(runtime_instance),
        labels: base_labels(runtime_instance).merge(
          "crucible.template_mode" => template.fetch(:mode),
          "crucible.host_binary" => binary,
          "crucible.host_binary_target" => target_path
        ),
        workdir: "/",
        volumes: [
          {
            type: "bind",
            source: source_path.to_s,
            target: target_path,
            read_only: true
          }
        ]
      )
    end

    def selected_template(runtime_definition, config)
      mode = config["template_mode"].presence ||
        runtime_definition.config_schema&.fetch("default_template_mode", nil).presence ||
        AgentCatalog.default_template_mode_for(runtime_definition.kind)

      template = AgentCatalog.template_for(runtime_definition.kind, mode)
      return template if template

      raise UnavailableTemplate, "Runtime template mode #{mode.inspect} is not available for #{runtime_definition.kind}."
    end

    def require_docker_compose_placement!(runtime_instance, template)
      return if runtime_instance.placement_kind == "docker_compose"

      raise UnavailableTemplate,
        "#{template.fetch(:mode)} template mode requires docker_compose placement so the host binary can be sandboxed by Compose."
    end

    def host_binary_path!(runtime_definition, template, config)
      binary = template.fetch(:binary)
      raw_path = config["host_binary_path"].presence || host_capabilities.executable_path(binary)

      unless raw_path.present?
        raise UnavailableTemplate,
          "#{runtime_definition.name} host_binary template requires host_binary_path or a #{binary} binary on PATH."
      end

      path = Pathname(raw_path.to_s).cleanpath
      raise UnavailableTemplate, "host_binary_path must be an absolute path for host_binary template mode." unless path.absolute?
      raise UnavailableTemplate, "Host binary path #{path} does not exist or is not a file." unless File.file?(path)
      raise UnavailableTemplate, "Host binary path #{path} is not executable." unless File.executable?(path)

      path
    end

    def host_binary_command(template, config, target_path)
      escaped_target = Shellwords.escape(target_path)
      configured_command = config["command"].presence
      command = configured_command || template[:default_command].presence || escaped_target

      if command.include?(HOST_BINARY_COMMAND_PLACEHOLDER)
        return command.gsub(HOST_BINARY_COMMAND_PLACEHOLDER, escaped_target)
      end

      configured_command.present? ? "#{escaped_target} #{configured_command}" : command
    end

    def base_labels(runtime_instance)
      runtime_definition = runtime_instance.runtime_definition

      {
        "crucible.runtime_instance_id" => runtime_instance.id.to_s,
        "crucible.runtime_definition_id" => runtime_definition.id.to_s,
        "crucible.workspace_id" => runtime_instance.workspace_id.to_s,
        "crucible.runtime_kind" => runtime_definition.kind
      }
    end
  end

  class OpenClaw < Base
  end

  class Codex < Base
  end

  class Hermes < Base
  end

  class Custom < Base
  end
end
