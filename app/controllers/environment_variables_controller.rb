# frozen_string_literal: true

class EnvironmentVariablesController < InertiaController
  before_action :set_workspace
  before_action :set_runtime_instance
  before_action :set_environment_variable, only: %i[update destroy]

  def create
    environment_variables.create!(
      environment_variable_params.merge(scope: environment_variable_scope)
    )

    redirect_to redirect_path, notice: "Environment variable saved."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to redirect_path, inertia: {errors: e.record.errors}
  end

  def update
    @environment_variable.update!(update_environment_variable_params)

    redirect_to redirect_path, notice: "Environment variable updated."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to redirect_path, inertia: {errors: e.record.errors}
  end

  def destroy
    @environment_variable.destroy!

    redirect_to redirect_path, notice: "Environment variable deleted."
  end

  private

  def set_workspace
    @workspace = Current.session.user.workspaces.find(params[:workspace_id])
  end

  def set_runtime_instance
    return if params[:runtime_instance_id].blank?

    @runtime_instance = @workspace.runtime_instances.find(params[:runtime_instance_id])
  end

  def set_environment_variable
    @environment_variable = environment_variables.find(params[:id])
  end

  def environment_variables
    if @runtime_instance
      @runtime_instance.environment_variables
    else
      EnvironmentVariable.system_variables
    end
  end

  def environment_variable_scope
    if @runtime_instance
      EnvironmentVariable::RUNTIME_INSTANCE_SCOPE
    else
      EnvironmentVariable::SYSTEM_SCOPE
    end
  end

  def environment_variable_params
    params.permit(:key, :value, :sensitive, :enabled)
  end

  def update_environment_variable_params
    attrs = environment_variable_params.to_h
    attrs.delete("value") if preserve_existing_sensitive_value?(attrs)
    attrs
  end

  def preserve_existing_sensitive_value?(attrs)
    @environment_variable.sensitive? && attrs.key?("value") && attrs["value"].blank?
  end

  def redirect_path
    workspace_path(@workspace, runtime_instance_id: selected_runtime_instance_id)
  end

  def selected_runtime_instance_id
    id = @runtime_instance&.id || params[:return_runtime_instance_id]
    return if id.blank?

    id if @workspace.runtime_instances.exists?(id:)
  end
end
