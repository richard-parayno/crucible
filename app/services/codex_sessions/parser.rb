# frozen_string_literal: true

module CodexSessions
  class Parser
    TOOL_OUTPUT_LIMIT = 8_000

    ParseResult = Data.define(
      :session,
      :timeline,
      :counts,
      :parse_errors,
      :record_count,
      :total_displayable
    )

    def initialize(path, include_timeline: true, timeline_offset: 0, timeline_limit: nil)
      @path = Pathname(path)
      @include_timeline = include_timeline
      @timeline_offset = [timeline_offset.to_i, 0].max
      @timeline_limit = timeline_limit ? [timeline_limit.to_i, 0].max : nil
      @session = default_session
      @timeline = []
      @counts = Hash.new(0)
      @parse_errors = []
      @record_count = 0
      @total_displayable = 0
    end

    def call
      File.foreach(@path).with_index(1) do |line, line_number|
        next if line.blank?

        parse_line(line, line_number)
      end

      ParseResult.new(
        session: finalize_session,
        timeline: @timeline,
        counts: @counts.to_h,
        parse_errors: @parse_errors,
        record_count: @record_count,
        total_displayable: @total_displayable
      )
    end

    private

    def parse_line(line, line_number)
      record = JSON.parse(line)
      @record_count += 1
      @counts["records"] += 1
      handle_record(record, line_number)
    rescue JSON::ParserError
      @parse_errors << {line: line_number, message: "Malformed JSON record."}
    end

    def handle_record(record, line_number)
      type = record["type"]
      payload = record["payload"] || {}
      timestamp = record["timestamp"] || payload["timestamp"]

      case type
      when "session_meta"
        merge_session_meta(payload, timestamp)
      when "turn_context"
        merge_turn_context(payload, timestamp)
      when "event_msg"
        handle_event(payload, timestamp, line_number)
      when "response_item"
        payload = payload["item"] if payload["item"].is_a?(Hash)
        handle_response_item(payload, timestamp, line_number)
      end
    end

    def merge_session_meta(payload, timestamp)
      @session.merge!(
        id: payload["session_id"] || payload["id"] || @session[:id],
        cwd: payload["cwd"] || @session[:cwd],
        started_at: payload["timestamp"] || timestamp || @session[:started_at],
        cli_version: display_value(payload["cli_version"]),
        source: display_value(payload["source"]),
        originator: display_value(payload["originator"]),
        thread_source: display_value(payload["thread_source"])
      )
    end

    def merge_turn_context(payload, timestamp)
      @session[:cwd] ||= payload["cwd"]
      @session[:started_at] ||= timestamp
      @counts["turns"] += 1
    end

    def handle_event(payload, timestamp, line_number)
      event_type = payload["type"]
      return unless %w[agent_message task_started task_complete user_message].include?(event_type)

      message = payload["message"] || payload["last_agent_message"]
      return if message.blank? && event_type != "task_started" && event_type != "task_complete"

      kind = event_type == "user_message" ? "user_message" : "agent_status"
      @counts[kind.pluralize] += 1
      return unless capture_timeline_item?

      append_timeline(
        kind:,
        timestamp:,
        line_number:,
        role: event_type == "user_message" ? "user" : "agent",
        event_type:,
        text: sanitize_text(message || titleize(event_type))
      )
    end

    def handle_response_item(payload, timestamp, line_number)
      case payload["type"]
      when "message"
        handle_message(payload, timestamp, line_number)
      when "function_call", "custom_tool_call", "web_search_call", "tool_search_call"
        handle_tool_call(payload, timestamp, line_number)
      when "function_call_output", "custom_tool_call_output", "tool_search_output"
        handle_tool_output(payload, timestamp, line_number)
      end
    end

    def handle_message(payload, timestamp, line_number)
      role = payload["role"]
      return if role == "developer"
      return unless %w[user assistant].include?(role)

      text = extract_text(payload["content"])
      return if text.blank?

      @counts["#{role}_messages"] += 1
      capture_timeline_item = capture_timeline_item?
      sanitized_text = nil

      if role == "user" && @session[:title].blank?
        sanitized_text = sanitize_text(text)
        @session[:title] = sanitized_text.truncate(120)
      end

      return unless capture_timeline_item

      sanitized_text ||= sanitize_text(text)
      append_timeline(
        kind: "#{role}_message",
        timestamp:,
        line_number:,
        role:,
        text: sanitized_text
      )
    end

    def handle_tool_call(payload, timestamp, line_number)
      @counts["tool_calls"] += 1
      return unless capture_timeline_item?

      append_timeline(
        kind: "tool_call",
        timestamp:,
        line_number:,
        call_id: payload["call_id"] || payload["id"],
        name: payload["name"] || payload.dig("action", "type") || payload["type"],
        status: payload["status"],
        arguments: sanitize_value(parse_possible_json(payload["arguments"] || payload["input"] || payload["action"]))
      )
    end

    def handle_tool_output(payload, timestamp, line_number)
      @counts["tool_outputs"] += 1
      return unless capture_timeline_item?

      output = sanitize_value(parse_possible_json(payload["output"] || payload["tools"]))
      truncated = false

      if output.is_a?(String) && output.length > TOOL_OUTPUT_LIMIT
        output = output.truncate(TOOL_OUTPUT_LIMIT, omission: "\n[TRUNCATED]")
        truncated = true
      end

      append_timeline(
        kind: "tool_output",
        timestamp:,
        line_number:,
        call_id: payload["call_id"],
        status: payload["status"],
        output:,
        truncated:
      )
    end

    def append_timeline(attributes)
      @timeline << attributes.compact
    end

    def capture_timeline_item?
      return false unless @include_timeline

      index = @total_displayable
      @total_displayable += 1

      return false if index < @timeline_offset
      return false if @timeline_limit && @timeline.length >= @timeline_limit

      true
    end

    def extract_text(content)
      case content
      when String
        content
      when Array
        content.filter_map { |item| extract_text(item) }.join("\n\n")
      when Hash
        content["text"] || content["content"] || content["message"]
      end
    end

    def parse_possible_json(value)
      return value unless value.is_a?(String)

      JSON.parse(value)
    rescue JSON::ParserError
      value
    end

    def sanitize_text(value)
      Redactor.call(value.to_s)
    end

    def sanitize_value(value)
      Redactor.call(value)
    end

    def display_value(value)
      sanitized = sanitize_value(value)

      case sanitized
      when nil
        nil
      when String
        sanitized
      else
        JSON.generate(sanitized)
      end
    rescue JSON::GeneratorError
      sanitized.to_s
    end

    def finalize_session
      @session[:id] ||= @path.basename(".jsonl").to_s.sub(/\Arollout-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}-/, "")
      @session[:title] ||= "Untitled Codex session"
      @session[:path] = @path.to_s
      @session
    end

    def default_session
      stat = @path.stat
      {
        id: nil,
        title: nil,
        cwd: nil,
        started_at: nil,
        updated_at: stat.mtime.iso8601,
        cli_version: nil,
        source: nil,
        originator: nil,
        thread_source: nil,
        path: @path.to_s
      }
    end

    def titleize(value)
      value.to_s.tr("_", " ").capitalize
    end
  end
end
