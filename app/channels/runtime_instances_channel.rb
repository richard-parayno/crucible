# frozen_string_literal: true

class RuntimeInstancesChannel < ApplicationCable::Channel
  def subscribed
    workspace = current_session.user.workspaces.find(params[:workspace_id])
    stream_for workspace
  end
end
