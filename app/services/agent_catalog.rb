# frozen_string_literal: true

class AgentCatalog
  USER_FACING_KINDS = %w[codex claude opencode hermes openclaw].freeze

  TEMPLATE_CONFIG_FIELDS = {
    "command" => "Shell command executed inside the Compose-managed runtime",
    "config_mount_path" => "Container path where the runtime-specific Docker config volume is mounted",
    "config_volume_enabled" => "Whether to mount a runtime-specific Docker config volume",
    "config_volume_name" => "Docker volume name used for runtime-specific agent configuration",
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
      metadata: {
        user_facing: true,
        trust_level: "official_upstream",
        verified_managed_install_available: false,
        install_sources: [
          {
            kind: "npm",
            name: "@openai/codex",
            url: "https://www.npmjs.com/package/@openai/codex",
            package: "@openai/codex"
          },
          {
            kind: "github_release",
            name: "openai/codex releases",
            url: "https://github.com/openai/codex/releases",
            repository: "openai/codex"
          }
        ],
        trusted_urls: [
          {label: "Source", url: "https://github.com/openai/codex"},
          {label: "Releases", url: "https://github.com/openai/codex/releases"},
          {label: "npm", url: "https://www.npmjs.com/package/@openai/codex"}
        ],
        version_pin: {
          package: "@openai/codex",
          field: "npm_package_version",
          example: "@openai/codex@<version>"
        },
        verification: {
          sha256: nil,
          integrity: "npm registry dist.integrity",
          sigstore: nil
        }
      },
      templates: [
        {
          mode: "managed_image",
          name: "Managed image",
          description: "Run Codex from a Compose-managed image template.",
          container_image: "node:24-alpine",
          default_command: "echo 'Codex managed image template is not configured yet.' && tail -f /dev/null",
          config_mount_path: "/root/.codex"
        },
        {
          mode: "host_binary",
          name: "Host binary",
          description: "Use host Codex binary detection as an input to a Compose sandbox template; the catalog does not execute Codex directly on the host.",
          binary: "codex",
          container_image: "node:24-alpine",
          default_command: "{{host_binary}} --help && tail -f /dev/null",
          config_mount_path: "/root/.codex"
        }
      ]
    },
    {
      kind: "claude",
      name: "Claude Code",
      description: "Claude Code agent runtime for Compose-managed workspaces.",
      container_image: "node:24-alpine",
      default_command: "echo 'Claude Code runtime template is not configured yet.' && tail -f /dev/null",
      binary: "claude",
      process_names: ["claude"],
      metadata: {
        user_facing: true,
        trust_level: "official_upstream",
        verified_managed_install_available: false,
        install_sources: [
          {
            kind: "npm",
            name: "@anthropic-ai/claude-code",
            url: "https://www.npmjs.com/package/@anthropic-ai/claude-code",
            package: "@anthropic-ai/claude-code"
          },
          {
            kind: "release_manifest",
            name: "Anthropic Claude Code release manifest",
            url: "https://docs.anthropic.com/en/docs/claude-code/setup"
          }
        ],
        trusted_urls: [
          {label: "Docs", url: "https://docs.anthropic.com/en/docs/claude-code"},
          {label: "Install docs", url: "https://docs.anthropic.com/en/docs/claude-code/setup"},
          {label: "npm", url: "https://www.npmjs.com/package/@anthropic-ai/claude-code"}
        ],
        version_pin: {
          package: "@anthropic-ai/claude-code",
          field: "npm_package_version",
          example: "@anthropic-ai/claude-code@<version>"
        },
        verification: {
          sha256: nil,
          integrity: "npm registry dist.integrity",
          sigstore: nil
        }
      },
      templates: [
        {
          mode: "managed_image",
          name: "Managed image",
          description: "Run Claude Code from a Compose-managed image template.",
          container_image: "node:24-alpine",
          default_command: "echo 'Claude Code managed image template is not configured yet.' && tail -f /dev/null",
          config_mount_path: "/root/.claude"
        },
        {
          mode: "host_binary",
          name: "Host binary",
          description: "Use host Claude Code binary detection as an input to a Compose sandbox template; the catalog does not execute Claude Code directly on the host.",
          binary: "claude",
          container_image: "node:24-alpine",
          default_command: "{{host_binary}} --help && tail -f /dev/null",
          config_mount_path: "/root/.claude"
        }
      ]
    },
    {
      kind: "opencode",
      name: "OpenCode",
      description: "OpenCode agent runtime for Compose-managed workspaces.",
      container_image: "node:24-alpine",
      default_command: "echo 'OpenCode runtime template is not configured yet.' && tail -f /dev/null",
      binary: "opencode",
      process_names: ["opencode"],
      metadata: {
        user_facing: true,
        trust_level: "community_upstream",
        verified_managed_install_available: false,
        install_sources: [
          {
            kind: "npm",
            name: "opencode-ai",
            url: "https://www.npmjs.com/package/opencode-ai",
            package: "opencode-ai",
            binary: "opencode"
          },
          {
            kind: "github_release",
            name: "anomalyco/opencode releases",
            url: "https://github.com/anomalyco/opencode/releases",
            repository: "anomalyco/opencode"
          }
        ],
        trusted_urls: [
          {label: "Source", url: "https://github.com/anomalyco/opencode"},
          {label: "Releases", url: "https://github.com/anomalyco/opencode/releases"},
          {label: "npm", url: "https://www.npmjs.com/package/opencode-ai"}
        ],
        version_pin: {
          package: "opencode-ai",
          field: "npm_package_version",
          example: "opencode-ai@<version>"
        },
        verification: {
          sha256: nil,
          integrity: "npm registry dist.integrity",
          sigstore: nil
        }
      },
      templates: [
        {
          mode: "managed_image",
          name: "Managed image",
          description: "Run OpenCode from a Compose-managed image template.",
          container_image: "node:24-alpine",
          default_command: "echo 'OpenCode managed image template is not configured yet.' && tail -f /dev/null",
          config_mount_path: "/root/.config/opencode"
        },
        {
          mode: "host_binary",
          name: "Host binary",
          description: "Use host OpenCode binary detection as an input to a Compose sandbox template; the catalog does not execute OpenCode directly on the host.",
          binary: "opencode",
          container_image: "node:24-alpine",
          default_command: "{{host_binary}} --help && tail -f /dev/null",
          config_mount_path: "/root/.config/opencode"
        }
      ]
    },
    {
      kind: "openclaw",
      name: "OpenClaw",
      description: "OpenClaw agent runtime for Compose-managed workspaces.",
      container_image: "node:24-alpine",
      default_command: "echo 'OpenClaw runtime template is not configured yet.' && tail -f /dev/null",
      binary: "openclaw",
      process_names: ["openclaw"],
      metadata: {
        user_facing: true,
        trust_level: "community_upstream",
        verified_managed_install_available: false,
        install_sources: [
          {
            kind: "npm",
            name: "openclaw",
            url: "https://www.npmjs.com/package/openclaw",
            package: "openclaw"
          },
          {
            kind: "github_release",
            name: "openclaw/openclaw releases",
            url: "https://github.com/openclaw/openclaw/releases",
            repository: "openclaw/openclaw"
          },
          {
            kind: "release_manifest",
            name: "openclaw/openclaw release manifest",
            url: "https://github.com/openclaw/openclaw/releases/latest"
          }
        ],
        trusted_urls: [
          {label: "Source", url: "https://github.com/openclaw/openclaw"},
          {label: "Releases", url: "https://github.com/openclaw/openclaw/releases"},
          {label: "npm", url: "https://www.npmjs.com/package/openclaw"}
        ],
        version_pin: {
          package: "openclaw",
          field: "npm_package_version",
          example: "openclaw@<version>"
        },
        verification: {
          sha256: "release asset sha256 when published",
          integrity: "npm registry dist.integrity",
          sigstore: nil
        }
      },
      templates: [
        {
          mode: "managed_image",
          name: "Managed image",
          description: "Run OpenClaw from a Compose-managed image template.",
          container_image: "node:24-alpine",
          default_command: "echo 'OpenClaw managed image template is not configured yet.' && tail -f /dev/null",
          config_mount_path: "/root/.openclaw"
        },
        {
          mode: "host_binary",
          name: "Host binary",
          description: "Use host OpenClaw binary detection as an input to a Compose sandbox template; the catalog does not execute OpenClaw directly on the host.",
          binary: "openclaw",
          container_image: "node:24-alpine",
          default_command: "{{host_binary}} --help && tail -f /dev/null",
          config_mount_path: "/root/.openclaw"
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
      process_names: ["hermes-agent", "hermes"],
      metadata: {
        user_facing: true,
        trust_level: "community_upstream",
        verified_managed_install_available: false,
        install_sources: [
          {
            kind: "pypi",
            name: "hermes-agent",
            url: "https://pypi.org/project/hermes-agent/",
            package: "hermes-agent"
          },
          {
            kind: "source",
            name: "NousResearch Hermes",
            url: "https://github.com/NousResearch/hermes-agent",
            repository: "NousResearch/hermes-agent"
          }
        ],
        trusted_urls: [
          {label: "Docs", url: "https://hermes-agent.nousresearch.com/"},
          {label: "Source", url: "https://github.com/NousResearch/hermes-agent"},
          {label: "PyPI", url: "https://pypi.org/project/hermes-agent/"}
        ],
        version_pin: {
          package: "hermes-agent",
          field: "pypi_package_version",
          example: "hermes-agent==<version>"
        },
        verification: {
          sha256: "PyPI file digests",
          integrity: nil,
          sigstore: "PyPI provenance when published"
        }
      },
      templates: [
        {
          mode: "managed_image",
          name: "Managed image",
          description: "Run Hermes Agent from a Compose-managed image template.",
          container_image: "node:24-alpine",
          default_command: "echo 'Hermes managed image template is not configured yet.' && tail -f /dev/null",
          config_mount_path: "/root/.config/hermes-agent"
        },
        {
          mode: "host_binary",
          name: "Host binary",
          description: "Use host Hermes Agent binary detection as an input to a Compose sandbox template; the catalog does not execute Hermes Agent directly on the host.",
          binary: "hermes-agent",
          container_image: "node:24-alpine",
          default_command: "{{host_binary}} --help && tail -f /dev/null",
          config_mount_path: "/root/.config/hermes-agent"
        }
      ]
    },
    {
      kind: "custom",
      name: "Custom Runtime",
      description: "A configurable runtime for local Compose orchestration smoke tests.",
      container_image: "alpine:latest",
      default_command: "while true; do echo \"crucible runtime heartbeat $(date -Iseconds)\"; sleep 10; done",
      process_names: [],
      metadata: {
        user_facing: false,
        trust_level: "local_custom",
        verified_managed_install_available: false,
        install_sources: [],
        trusted_urls: [],
        version_pin: {
          field: nil,
          example: nil
        },
        verification: {
          sha256: nil,
          integrity: nil,
          sigstore: nil
        }
      },
      templates: [
        {
          mode: "custom",
          name: "Custom",
          description: "Provide a container image and command for a Compose-managed custom runtime.",
          container_image: "alpine:latest",
          default_command: "while true; do echo \"crucible runtime heartbeat $(date -Iseconds)\"; sleep 10; done",
          config_mount_path: "/root/.config/crucible-agent"
        }
      ]
    }
  ].freeze

  class << self
    def entries
      deep_dup(AGENTS)
    end

    def user_facing_kinds
      USER_FACING_KINDS.dup
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

    def user_facing_runtime_definitions
      definitions = runtime_definitions.index_by { |definition| definition.fetch(:kind) }

      user_facing_kinds.map { |kind| definitions.fetch(kind) }
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

    def detectable_runtimes
      entries.filter_map do |agent|
        binary = agent[:binary]
        process_names = Array(agent[:process_names])
        next if binary.blank? && process_names.blank?

        {
          kind: agent.fetch(:kind),
          name: agent.fetch(:name),
          binary:,
          process_names: process_names.presence || [binary]
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
      metadata = agent.fetch(:metadata)

      TEMPLATE_CONFIG_FIELDS.merge(
        "templates" => agent.fetch(:templates),
        "default_template_mode" => agent.fetch(:templates).first.fetch(:mode),
        "install_sources" => stringify_keys(metadata.fetch(:install_sources)),
        "verified_artifacts" => verified_artifacts_for(metadata),
        "trust_level" => metadata.fetch(:trust_level),
        "verification_summary" => verification_summary_for(agent),
        "docs_url" => docs_url_for(agent),
        "source_url" => source_url_for(agent),
        "version_pin" => stringify_keys(metadata.fetch(:version_pin)),
        "trusted_urls" => stringify_keys(metadata.fetch(:trusted_urls)),
        "verified_managed_install_available" => false
      )
    end

    def docs_url_for(agent)
      case agent.fetch(:kind)
      when "claude"
        "https://docs.anthropic.com/en/docs/claude-code"
      when "hermes"
        "https://hermes-agent.nousresearch.com/"
      else
        source_url_for(agent)
      end
    end

    def source_url_for(agent)
      metadata = agent.fetch(:metadata)
      source = metadata.fetch(:trusted_urls).find { |url| url.fetch(:label) == "Source" }
      source ||= metadata.fetch(:install_sources).find { |install_source| install_source.fetch(:kind).in?(%w[source npm pypi]) }

      source&.fetch(:url)
    end

    def verification_summary_for(agent)
      case agent.fetch(:kind)
      when "custom"
        "Custom runtime definitions are internal and are not offered as supported Add Agent templates."
      when "hermes"
        "Pin the PyPI package version and verify PyPI file digests; Sigstore provenance can be used when published by PyPI."
      else
        "Pin the package version and verify registry integrity metadata before any managed install. Release manifest sources are documentation only until separately verified."
      end
    end

    def verified_artifacts_for(metadata)
      verification = metadata.fetch(:verification)
      artifacts = []

      artifacts << {kind: "sha256", value: verification.fetch(:sha256), available: verification.fetch(:sha256).present?}
      artifacts << {kind: "integrity", value: verification.fetch(:integrity), available: verification.fetch(:integrity).present?}
      artifacts << {kind: "sigstore", value: verification.fetch(:sigstore), available: verification.fetch(:sigstore).present?}
      stringify_keys(artifacts)
    end

    def stringify_keys(value)
      case value
      when Array
        value.map { |item| stringify_keys(item) }
      when Hash
        value.to_h { |key, item| [key.to_s, stringify_keys(item)] }
      else
        value
      end
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
