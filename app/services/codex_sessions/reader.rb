# frozen_string_literal: true

module CodexSessions
  class Reader
    DEFAULT_PAGE = 1
    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 100
    DEFAULT_TIMELINE_OFFSET = 0
    DEFAULT_TIMELINE_LIMIT = 100
    MAX_TIMELINE_LIMIT = 200

    def initialize(root: Inventory.default_root, current_repo: Rails.root.to_s)
      @root = root
      @current_repo = current_repo
    end

    def index_props(page: DEFAULT_PAGE, per_page: DEFAULT_PER_PAGE)
      result = inventory(page:, per_page:).call

      {
        sessions: result.sessions,
        source: result.source,
        pagination: result.pagination
      }
    end

    def show_props(session_id, timeline_offset: DEFAULT_TIMELINE_OFFSET, timeline_limit: DEFAULT_TIMELINE_LIMIT)
      offset = normalize_non_negative_integer(timeline_offset, DEFAULT_TIMELINE_OFFSET)
      limit = normalize_bounded_integer(timeline_limit, DEFAULT_TIMELINE_LIMIT, MAX_TIMELINE_LIMIT)
      session = inventory.find(session_id)
      return nil unless session

      parsed = Parser.new(
        session.fetch(:path),
        timeline_offset: offset,
        timeline_limit: limit
      ).call

      {
        session: session.merge(
          counts: parsed.counts,
          parse_error_count: parsed.parse_errors.size,
          parse_errors: parsed.parse_errors
        ),
        timeline: parsed.timeline,
        timeline_page: {
          offset:,
          limit:,
          returned_count: parsed.timeline.size,
          total_displayable: parsed.total_displayable,
          has_next_page: offset + parsed.timeline.size < parsed.total_displayable
        }
      }
    rescue Errno::EACCES, Errno::EPERM
      nil
    end

    private

    def inventory(page: DEFAULT_PAGE, per_page: DEFAULT_PER_PAGE)
      Inventory.new(
        root: @root,
        current_repo: @current_repo,
        page: normalize_non_negative_integer(page, DEFAULT_PAGE, minimum: 1),
        per_page: normalize_bounded_integer(per_page, DEFAULT_PER_PAGE, MAX_PER_PAGE)
      )
    end

    def normalize_bounded_integer(value, default, max)
      [[Integer(value.presence || default), 1].max, max].min
    rescue ArgumentError, TypeError
      default
    end

    def normalize_non_negative_integer(value, default, minimum: 0)
      [Integer(value.presence || default), minimum].max
    rescue ArgumentError, TypeError
      default
    end
  end
end
