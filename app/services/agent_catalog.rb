# frozen_string_literal: true

class AgentCatalog
  TEMPLATE_CONFIG_FIELDS = {
    "command" => "Shell command executed inside the Compose-managed runtime",
    "container_image" => "Container image used for the Compose-managed runtime",
    "host_binary_path" => "Absolute host path to a binary that will be bind-mounted read-only into the Compose-managed runtime",
    "template_mode" => "Catalog template mode selected for this runtime"
  }.freeze

  AGENTS = [
    {
      kind: "codex",
      name: "Codex",
      description: "Codex agent runtime for Compose-managed workspaces.",
      container_image: "node:24-alpine",
      default_command: "echo 'Codex runtime template is not configured yet.' && tail -f /dev/null",
      binary: "codex",
      templates: [
        {
          mode: "managed_image",
          name: "Managed image",
          description: "Run Codex from a Compose-managed image template.",
          container_image: "node:24-alpine",
          default_command: "echo 'Codex managed image template is not configured yet.' && tail -f /dev/null"
        },
        {
          mode: "host_binary",
          name: "Host binary",
          description: "Use host Codex binary detection as an input to a Compose sandbox template; the catalog does not execute Codex directly on the host.",
          binary: "codex",
          container_image: "node:24-alpine",
          default_command: "{{host_binary}} --help && tail -f /dev/null"
        }
      ]
    },
    {
      kind: "openclaw",
      name: "OpenClaw",
      description: "OpenClaw agent runtime for Compose-managed workspaces.",
      container_image: "node:24-alpine",
      default_command: "npm install -g openclaw && openclaw --help && tail -f /dev/null",
      binary: "openclaw",
      templates: [
        {
          mode: "managed_image",
          name: "Managed image",
          description: "Run OpenClaw from a Compose-managed image template.",
          container_image: "node:24-alpine",
          default_command: "npm install -g openclaw && openclaw --help && tail -f /dev/null"
        },
        {
          mode: "host_binary",
          name: "Host binary",
          description: "Use host OpenClaw binary detection as an input to a Compose sandbox template; the catalog does not execute OpenClaw directly on the host.",
          binary: "openclaw",
          container_image: "node:24-alpine",
          default_command: "{{host_binary}} --help && tail -f /dev/null"
        }
      ]
    },
    {
      kind: "hermes",
      name: "Hermes Agent",
      description: "Hermes agent runtime for Compose-managed workspaces.",
      container_image: "node:24-alpine",
      default_command: "echo 'Hermes agent command not configured yet.' && tail -f /dev/null",
      binary: "hermes-agent",
      templates: [
        {
          mode: "managed_image",
          name: "Managed image",
          description: "Run Hermes Agent from a Compose-managed image template.",
          container_image: "node:24-alpine",
          default_command: "echo 'Hermes managed image template is not configured yet.' && tail -f /dev/null"
        },
        {
          mode: "host_binary",
          name: "Host binary",
          description: "Use host Hermes Agent binary detection as an input to a Compose sandbox template; the catalog does not execute Hermes Agent directly on the host.",
          binary: "hermes-agent",
          container_image: "node:24-alpine",
          default_command: "{{host_binary}} --help && tail -f /dev/null"
        }
      ]
    },
    {
      kind: "custom",
      name: "Custom Runtime",
      description: "A configurable runtime for local Compose orchestration smoke tests.",
      container_image: "alpine:latest",
      default_command: "while true; do echo \"crucible runtime heartbeat $(date -Iseconds)\"; sleep 10; done",
      templates: [
        {
          mode: "custom",
          name: "Custom",
          description: "Provide a container image and command for a Compose-managed custom runtime.",
          container_image: "alpine:latest",
          default_command: "while true; do echo \"crucible runtime heartbeat $(date -Iseconds)\"; sleep 10; done"
        }
      ]
    }
  ].freeze

  class << self
    def entries
      deep_dup(AGENTS)
    end

    def runtime_definitions
      entries.map do |agent|
        {
          kind: agent.fetch(:kind),
          name: agent.fetch(:name),
          description: agent.fetch(:description),
          container_image: agent.fetch(:container_image),
          default_command: agent.fetch(:default_command),
          default_env: {},
          config_schema: config_schema_for(agent)
        }
      end
    end

    def host_binary_templates
      entries.filter_map do |agent|
        template = agent.fetch(:templates).find { |candidate| candidate.fetch(:mode) == "host_binary" }
        next unless template

        {
          kind: agent.fetch(:kind),
          name: agent.fetch(:name),
          binary: template.fetch(:binary)
        }
      end
    end

    def template_for(kind, mode)
      agent = entries.find { |candidate| candidate.fetch(:kind) == kind }
      return unless agent

      agent.fetch(:templates).find { |template| template.fetch(:mode) == mode }
    end

    def default_template_mode_for(kind)
      agent = entries.find { |candidate| candidate.fetch(:kind) == kind }
      agent&.fetch(:templates)&.first&.fetch(:mode)
    end

    private

    def config_schema_for(agent)
      TEMPLATE_CONFIG_FIELDS.merge(
        "templates" => agent.fetch(:templates),
        "default_template_mode" => agent.fetch(:templates).first.fetch(:mode)
      )
    end

    def deep_dup(value)
      case value
      when Array
        value.map { |item| deep_dup(item) }
      when Hash
        value.transform_values { |item| deep_dup(item) }
      else
        value
      end
    end
  end
end
