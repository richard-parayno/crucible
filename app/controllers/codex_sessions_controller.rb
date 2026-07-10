# frozen_string_literal: true

class CodexSessionsController < InertiaController
  def index
    render inertia: CodexSessions::Reader.new.index_props(
      page: params[:page],
      per_page: params[:per_page]
    )
  end

  def show
    props = CodexSessions::Reader.new.show_props(
      params[:session_id],
      timeline_offset: params[:timeline_offset],
      timeline_limit: params[:timeline_limit]
    )
    return head :not_found unless props

    render inertia: props
  end
end
