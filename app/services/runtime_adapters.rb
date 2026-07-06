# frozen_string_literal: true

module RuntimeAdapters
  AdapterSpec = Data.define(:image, :command, :env, :labels, :workdir)

  class UnknownAdapter < StandardError; end

  def self.for(kind)
    case kind
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
    def spec_for(runtime_instance)
      runtime_definition = runtime_instance.runtime_definition
      AdapterSpec.new(
        image: runtime_instance.config["container_image"].presence || runtime_definition.container_image,
        command: runtime_instance.config["command"].presence || runtime_definition.default_command,
        env: runtime_definition.default_env.merge(runtime_instance.env),
        labels: {
          "crucible.runtime_instance_id" => runtime_instance.id.to_s,
          "crucible.workspace_id" => runtime_instance.workspace_id.to_s,
          "crucible.runtime_kind" => runtime_definition.kind
        },
        workdir: "/"
      )
    end

    def health_status(_runtime_instance, container_state)
      return ["running", nil] if container_state == "running"

      ["unhealthy", "Container state is #{container_state}"]
    end
  end

  class OpenClaw < Base
  end

  class Hermes < Base
  end

  class Custom < Base
  end
end
