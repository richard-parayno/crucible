# frozen_string_literal: true

class EnvironmentVariableResolver
  def self.call(runtime_instance)
    new(runtime_instance).call
  end

  def initialize(runtime_instance)
    @runtime_instance = runtime_instance
  end

  def call
    runtime_definition_env
      .merge(system_env)
      .merge(runtime_variable_env)
      .merge(runtime_instance_env)
      .merge(runtime_instance_config_env)
  end

  private

  attr_reader :runtime_instance

  def runtime_definition_env
    normalized_env(runtime_instance.runtime_definition.default_env)
  end

  def system_env
    variable_env(EnvironmentVariable.system_variables.enabled.order(:key))
  end

  def runtime_variable_env
    variable_env(runtime_instance.environment_variables.enabled.order(:key))
  end

  def runtime_instance_env
    normalized_env(runtime_instance.env)
  end

  def runtime_instance_config_env
    normalized_env(runtime_instance.config&.fetch("env", nil))
  end

  def variable_env(environment_variables)
    environment_variables.each_with_object({}) do |environment_variable, env|
      env[environment_variable.key] = environment_variable.value
    end
  end

  def normalized_env(source)
    return {} unless source.respond_to?(:to_h)

    source.to_h.each_with_object({}) do |(key, value), env|
      env[key.to_s] = value.to_s
    end
  end
end
