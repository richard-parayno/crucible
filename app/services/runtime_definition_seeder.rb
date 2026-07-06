# frozen_string_literal: true

class RuntimeDefinitionSeeder
  DEFINITIONS = [
    {
      kind: "openclaw",
      name: "OpenClaw",
      description: "OpenClaw local runtime placeholder. Override the command once the target image/install path is chosen.",
      container_image: "node:24-alpine",
      default_command: "npm install -g openclaw && openclaw --help && tail -f /dev/null",
      default_env: {},
      config_schema: {
        command: "Shell command executed inside the container",
        container_image: "Container image used for the runtime"
      }
    },
    {
      kind: "hermes",
      name: "Hermes Agent",
      description: "Hermes local runtime placeholder. Override the image and command to match the runtime distribution.",
      container_image: "node:24-alpine",
      default_command: "echo 'Hermes agent command not configured yet.' && tail -f /dev/null",
      default_env: {},
      config_schema: {
        command: "Shell command executed inside the container",
        container_image: "Container image used for the runtime"
      }
    },
    {
      kind: "custom",
      name: "Custom Runtime",
      description: "A simple configurable runtime for local orchestration smoke tests.",
      container_image: "alpine:latest",
      default_command: "while true; do echo \"crucible runtime heartbeat $(date -Iseconds)\"; sleep 10; done",
      default_env: {},
      config_schema: {
        command: "Shell command executed inside the container",
        container_image: "Container image used for the runtime"
      }
    }
  ].freeze

  def self.call
    DEFINITIONS.each do |attributes|
      RuntimeDefinition.find_or_initialize_by(kind: attributes[:kind]).tap do |runtime_definition|
        runtime_definition.assign_attributes(attributes)
        runtime_definition.save!
      end
    end
  end
end
