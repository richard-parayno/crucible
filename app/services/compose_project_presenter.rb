# frozen_string_literal: true

class ComposeProjectPresenter
  def self.call(runtime_instance, project_writer: ComposeProjectWriter.new)
    new(runtime_instance, project_writer:).call
  end

  def initialize(runtime_instance, project_writer:)
    @runtime_instance = runtime_instance
    @project_writer = project_writer
  end

  def call
    return unless runtime_instance.placement_kind == "docker_compose"

    project = project_writer.project_for(runtime_instance)

    {
      directory_path: project.directory.to_s,
      compose_path: project.compose_path.to_s,
      env_path: project.env_path.to_s,
      project_name: project.project_name,
      service_name: project.service_name,
      commands: commands_for(project)
    }
  end

  private

  attr_reader :runtime_instance, :project_writer

  def commands_for(project)
    {
      up: compose_command(project, "up", "--detach", project.service_name),
      stop: compose_command(project, "stop", project.service_name),
      restart: compose_command(project, "restart", project.service_name),
      logs: compose_command(project, "logs", "--tail", "100", project.service_name),
      ps: compose_command(project, "ps", "--all", project.service_name),
      exec_shell: compose_command(project, "exec", project.service_name, "sh")
    }
  end

  def compose_command(project, *args)
    [
      "docker",
      "compose",
      "-p",
      project.project_name,
      "-f",
      project.compose_path.to_s,
      "--env-file",
      project.env_path.to_s,
      *args
    ]
  end
end
