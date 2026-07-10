# frozen_string_literal: true

require "base64"

module CodexSessions
  class Inventory
    Result = Data.define(:sessions, :source, :pagination)

    def self.default_root
      configured_home = ENV["CODEX_HOME"].presence || "~/.codex"
      ENV["CODEX_SESSIONS_ROOT"].presence || File.join(configured_home, "sessions")
    end

    def call
      entries = session_entries
      visible_entries = entries.slice(@offset, @per_page) || []
      sessions = visible_entries.filter_map { |entry| summary_for(entry) }
      total_count = entries.size

      Result.new(
        sessions:,
        source: {
          root_path: @root.to_s,
          scanned_count: total_count,
          parsed_count: @scanned_count,
          unreadable_count: @unreadable_count,
          parse_errors: @parse_errors,
          cache: @cache_stats
        },
        pagination: pagination(total_count)
      )
    end

    def find(session_id)
      if (entry = entry_from_route_id(session_id))
        return summary_for(entry)
      end

      session_entries.lazy.filter_map { |entry| summary_for(entry) }.find { |session| session[:id] == session_id }
    end

    def initialize(root: self.class.default_root, current_repo: Rails.root.to_s, page: 1, per_page: 50)
      @root = Pathname(File.expand_path(root.to_s))
      @current_repo = File.expand_path(current_repo.to_s)
      @page = [page.to_i, 1].max
      @per_page = [[per_page.to_i, 1].max, 100].min
      @offset = (@page - 1) * @per_page
      @unreadable_count = 0
      @parse_errors = []
      @scanned_count = 0
      @cache_stats = {hits: 0, misses: 0}
    end

    private

    def session_entries
      return [] unless @root.directory?

      @root.glob("**/*.jsonl").filter_map do |path|
        entry_for(path)
      end.sort_by { |entry| [entry[:mtime].to_i, entry[:mtime_nsec], entry[:relative_path]] }.reverse
    end

    def entry_for(path)
      stat = path.stat

      {
        path:,
        relative_path: path.relative_path_from(@root).to_s,
        size: stat.size,
        mtime: stat.mtime,
        mtime_nsec: stat.mtime.nsec
      }
    rescue Errno::EACCES, Errno::EPERM
      @unreadable_count += 1
      nil
    end

    def summary_for(entry)
      key = cache_key(entry)
      cached = Rails.cache.read(key)

      if cached
        @cache_stats[:hits] += 1
        @parse_errors.concat(cached.fetch(:parse_errors, []))
        return cached.fetch(:session)
      end

      @cache_stats[:misses] += 1
      payload = summary_payload_for(entry)
      Rails.cache.write(key, payload)
      @parse_errors.concat(payload.fetch(:parse_errors, []))
      payload.fetch(:session)
    end

    def summary_payload_for(entry)
      @scanned_count += 1
      path = entry.fetch(:path)
      result = Parser.new(path, include_timeline: false).call
      parse_errors = result.parse_errors.map { |error| error.merge(path: path.to_s) }

      {
        session: result.session.merge(
          route_id: route_id(path),
          counts: result.counts,
          record_count: result.record_count,
          parse_error_count: result.parse_errors.size,
          current_repo: current_repo?(result.session[:cwd])
        ),
        parse_errors:
      }
    rescue Errno::EACCES, Errno::EPERM
      @unreadable_count += 1
      {session: nil, parse_errors: []}
    end

    def cache_key(entry)
      [
        "codex_sessions",
        "index_summary",
        @root.to_s,
        @current_repo,
        entry.fetch(:relative_path),
        entry.fetch(:size),
        entry.fetch(:mtime).to_i,
        entry.fetch(:mtime_nsec)
      ]
    end

    def route_id(path)
      relative_path = path.relative_path_from(@root).to_s

      Base64.urlsafe_encode64(relative_path, padding: false)
    end

    def entry_from_route_id(route_id)
      relative_path = Base64.urlsafe_decode64(route_id.to_s)
      return if relative_path.blank?

      relative = Pathname(relative_path)
      return if relative.absolute?
      return unless relative.extname == ".jsonl"

      clean_relative = relative.cleanpath
      return if clean_relative.to_s == "." || clean_relative.to_s.start_with?("../")

      path = @root.join(clean_relative).cleanpath
      return unless path.to_s == @root.join(clean_relative).cleanpath.to_s
      return unless path.to_s.start_with?("#{@root}/")
      return unless path.file?

      entry_for(path)
    rescue ArgumentError
      nil
    end

    def pagination(total_count)
      total_pages = (total_count.to_f / @per_page).ceil

      {
        page: @page,
        per_page: @per_page,
        total_count:,
        total_pages:,
        has_previous_page: @page > 1,
        has_next_page: @page < total_pages
      }
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
