# frozen_string_literal: true

module CodexSessions
  class Inventory
    Result = Data.define(:sessions, :source)

    def initialize(root: self.class.default_root, current_repo: Rails.root.to_s)
      @root = Pathname(File.expand_path(root.to_s))
      @current_repo = File.expand_path(current_repo.to_s)
      @unreadable_count = 0
      @parse_errors = []
      @scanned_count = 0
    end

    def self.default_root
      configured_home = ENV["CODEX_HOME"].presence || "~/.codex"
      ENV["CODEX_SESSIONS_ROOT"].presence || File.join(configured_home, "sessions")
    end

    def call
      sessions = session_paths.filter_map { |path| parse_path(path) }

      Result.new(
        sessions: sessions.sort_by { |session| session[:updated_at].to_s }.reverse,
        source: {
          root_path: @root.to_s,
          scanned_count: @scanned_count,
          unreadable_count: @unreadable_count,
          parse_errors: @parse_errors
        }
      )
    end

    def find(session_id)
      call.sessions.find { |session| session[:id] == session_id }
    end

    private

    def session_paths
      return [] unless @root.directory?

      @root.glob("**/*.jsonl").sort
    end

    def parse_path(path)
      @scanned_count += 1
      result = Parser.new(path, include_timeline: false).call
      @parse_errors.concat(
        result.parse_errors.map { |error| error.merge(path: path.to_s) }
      )

      result.session.merge(
        counts: result.counts,
        record_count: result.record_count,
        parse_error_count: result.parse_errors.size,
        current_repo: current_repo?(result.session[:cwd])
      )
    rescue Errno::EACCES, Errno::EPERM
      @unreadable_count += 1
      nil
    end

    def current_repo?(cwd)
      return false if cwd.blank?

      expanded_cwd = File.expand_path(cwd)
      expanded_cwd == @current_repo || expanded_cwd.start_with?("#{@current_repo}/")
    rescue ArgumentError
      false
    end
  end
end
