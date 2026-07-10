# frozen_string_literal: true

module CodexSessions
  class Redactor
    REDACTED = "[REDACTED]"
    SENSITIVE_KEY_PATTERN = /token|secret|password|key|authorization/i
    BEARER_PATTERN = /Bearer\s+[A-Za-z0-9._~+\/=-]+/
    ASSIGNMENT_PATTERN = /
      (?<key>[A-Za-z0-9_.-]*(?:token|secret|password|key|authorization)[A-Za-z0-9_.-]*)
      (?<separator>\s*[:=]\s*)
      (?:
        "(?<double_quoted>[^"]*)" |
        '(?<single_quoted>[^']*)' |
        (?<unquoted>[^\s,"'}\]]+)
      )
    /ix

    def self.call(value)
      new.call(value)
    end

    def call(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested_value), sanitized|
          sanitized[key] = sensitive_key?(key) ? REDACTED : call(nested_value)
        end
      when Array
        value.map { |nested_value| call(nested_value) }
      when String
        redact_string(value)
      else
        value
      end
    end

    private

    def sensitive_key?(key)
      key.to_s.match?(SENSITIVE_KEY_PATTERN)
    end

    def redact_string(value)
      value
        .gsub(BEARER_PATTERN, "Bearer #{REDACTED}")
        .gsub(ASSIGNMENT_PATTERN) do
          quote = Regexp.last_match[:double_quoted] ? "\"" : Regexp.last_match[:single_quoted] ? "'" : nil
          "#{Regexp.last_match[:key]}#{Regexp.last_match[:separator]}#{quote}#{REDACTED}#{quote}"
        end
    end
  end
end
