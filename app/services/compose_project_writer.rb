# frozen_string_literal: true

require "fileutils"
require "yaml"

class ComposeProjectWriter
  Project = Data.define(:directory, :compose_path, :env_path, :project_name, :service_name)

  SERVICE_NAME = "agent"

  def initialize(root: Rails.root.join("storage", "runtimes"))
    @root = Pathname(root)
  end

  def write(runtime_instance, adapter_spec)
    project = project_for(runtime_instance)

    FileUtils.mkdir_p(project.directory)
    project.compose_path.write(compose_payload(adapter_spec).to_yaml)
    project.env_path.write(env_payload(adapter_spec.env))

    project
  end

  def project_for(runtime_instance)
    directory = @root.join(runtime_instance.id.to_s)

    Project.new(
      directory:,
      compose_path: directory.join("compose.yml"),
      env_path: directory.join(".env"),
      project_name: project_name(runtime_instance),
      service_name: SERVICE_NAME
    )
  end

  private

  def compose_payload(adapter_spec)
    service = {
      "image" => adapter_spec.image,
      "working_dir" => adapter_spec.workdir,
      "command" => ["sh", "-lc", adapter_spec.command]
    }

    service["environment"] = env_references(adapter_spec.env) if adapter_spec.env.present?
    service["labels"] = adapter_spec.labels if adapter_spec.labels.present?
    service["volumes"] = volume_payloads(adapter_spec.volumes) if adapter_spec.volumes.present?

    {"services" => {SERVICE_NAME => service}}
  end

  def volume_payloads(volumes)
    volumes.map do |volume|
      {
        "type" => volume.fetch(:type, "bind"),
        "source" => volume.fetch(:source).to_s,
        "target" => volume.fetch(:target).to_s,
        "read_only" => volume.fetch(:read_only, false)
      }
    end
  end

  def env_references(env)
    env.keys.sort.index_with { |key| "${#{key}}" }
  end

  def env_payload(env)
    env.sort.map { |key, value| "#{key}=#{quote_env_value(value)}" }.join("\n").then do |content|
      content.present? ? "#{content}\n" : ""
    end
  end

  def quote_env_value(value)
    escaped = value.to_s.gsub("\\", "\\\\\\").gsub("\n", "\\n").gsub("'", "\\\\'")
    "'#{escaped}'"
  end

  def project_name(runtime_instance)
    kind = runtime_instance.runtime_definition.kind.to_s.parameterize.presence || "runtime"

    "crucible-#{runtime_instance.id}-#{kind}"
  end
end
