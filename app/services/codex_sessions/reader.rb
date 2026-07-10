# frozen_string_literal: true

module CodexSessions
  class Reader
    def initialize(root: Inventory.default_root, current_repo: Rails.root.to_s)
      @inventory = Inventory.new(root:, current_repo:)
    end

    def index_props
      result = @inventory.call

      {
        sessions: result.sessions,
        source: result.source
      }
    end

    def show_props(session_id)
      session = @inventory.find(session_id)
      return nil unless session

      parsed = Parser.new(session.fetch(:path)).call

      {
        session: session.merge(
          counts: parsed.counts,
          parse_error_count: parsed.parse_errors.size,
          parse_errors: parsed.parse_errors
        ),
        timeline: parsed.timeline
      }
    rescue Errno::EACCES, Errno::EPERM
      nil
    end
  end
end
