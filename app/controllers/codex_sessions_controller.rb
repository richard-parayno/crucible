# frozen_string_literal: true

class CodexSessionsController < InertiaController
  def index
    render inertia: CodexSessions::Reader.new.index_props
  end

  def show
    props = CodexSessions::Reader.new.show_props(params[:session_id])
    return head :not_found unless props

    render inertia: props
  end
end
