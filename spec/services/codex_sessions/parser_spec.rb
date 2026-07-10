# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe CodexSessions::Parser do
  let(:root) { Pathname(Dir.mktmpdir) }
  let(:path) { root.join("rollout-2026-07-10T10-00-00-parser-session.jsonl") }

  after do
    FileUtils.remove_entry(root)
  end

  it "parses valid metadata, messages, events, tool calls, and tool outputs" do
    write_records(
      [
        record(
          "session_meta",
          "session_id" => "parser-session",
          "cwd" => Rails.root.to_s,
          "timestamp" => "2026-07-10T10:00:00Z",
          "cli_version" => "1.0.0",
          "source" => "codex_cli",
          "originator" => "codex"
        ),
        record("turn_context", "turn_id" => "turn-1", "cwd" => Rails.root.to_s),
        record("event_msg", "type" => "agent_message", "message" => "Reading files"),
        response_item(
          "message",
          "role" => "user",
          "content" => [{"type" => "input_text", "text" => "Build a viewer"}]
        ),
        response_item(
          "message",
          "role" => "assistant",
          "content" => [{"type" => "output_text", "text" => "Done"}]
        ),
        response_item(
          "function_call",
          "name" => "exec_command",
          "call_id" => "call-1",
          "arguments" => {"cmd" => "ls"}.to_json
        ),
        response_item(
          "function_call_output",
          "call_id" => "call-1",
          "output" => "app\nconfig\n"
        ),
        record(
          "response_item",
          "item" => {
            "type" => "message",
            "role" => "assistant",
            "content" => [{"type" => "output_text", "text" => "Nested shape"}]
          }
        )
      ]
    )

    result = described_class.new(path).call

    expect(result.session).to include(
      id: "parser-session",
      title: "Build a viewer",
      cwd: Rails.root.to_s,
      cli_version: "1.0.0",
      source: "codex_cli",
      originator: "codex"
    )
    expect(result.counts).to include(
      "records" => 8,
      "turns" => 1,
      "agent_statuses" => 1,
      "user_messages" => 1,
      "assistant_messages" => 2,
      "tool_calls" => 1,
      "tool_outputs" => 1
    )
    expect(result.timeline.pluck(:kind)).to eq(
      %w[agent_status user_message assistant_message tool_call tool_output assistant_message]
    )
  end

  it "records malformed JSON without dropping the valid records" do
    path.write(
      [
        record("session_meta", "session_id" => "bad-json").to_json,
        "{bad json token=super-secret",
        response_item("message", "role" => "user", "content" => "Still parsed").to_json
      ].join("\n")
    )

    result = described_class.new(path).call

    expect(result.session[:id]).to eq("bad-json")
    expect(result.timeline.sole).to include(kind: "user_message", text: "Still parsed")
    expect(result.parse_errors.sole).to include(line: 2, message: "Malformed JSON record.")
    expect(result.parse_errors.to_json).not_to include("super-secret")
  end

  it "normalizes structured metadata before returning it to the UI" do
    write_records(
      [
        record(
          "session_meta",
          "session_id" => "metadata-session",
          "source" => {"surface" => "vscode", "api_key" => "secret"},
          "originator" => nil
        )
      ]
    )

    result = described_class.new(path).call

    expect(result.session[:source]).to eq({"surface" => "vscode", "api_key" => "[REDACTED]"}.to_json)
  end

  it "falls back when metadata is missing" do
    write_records(
      [
        response_item("message", "role" => "user", "content" => "Only prompt")
      ]
    )

    result = described_class.new(path).call

    expect(result.session).to include(
      id: "parser-session",
      title: "Only prompt",
      path: path.to_s
    )
  end

  it "omits unsafe records, redacts secret-like values, and truncates large outputs" do
    write_records(
      [
        record(
          "session_meta",
          "session_id" => "safe-session",
          "base_instructions" => "system prompt"
        ),
        response_item("message", "role" => "developer", "content" => "developer note"),
        response_item("reasoning", "encrypted_content" => "ciphertext"),
        response_item(
          "message",
          "role" => "user",
          "content" => "token=abc123 OPENAI_API_KEY=\"sk-secret\" password: 'quoted-secret'"
        ),
        response_item(
          "function_call",
          "name" => "exec",
          "call_id" => "call-1",
          "arguments" => {"api_key" => "abc123", "cmd" => "print"}.to_json
        ),
        response_item(
          "function_call_output",
          "call_id" => "call-1",
          "output" => [
            {"type" => "session_meta", "payload" => {"base_instructions" => {"text" => "system prompt"}}}.to_json,
            {"type" => "response_item", "payload" => {"type" => "message", "role" => "developer", "content" => "developer note"}}.to_json,
            {"type" => "response_item", "payload" => {"type" => "reasoning", "encrypted_content" => "ciphertext"}}.to_json,
            "x" * (described_class::TOOL_OUTPUT_LIMIT + 20)
          ].join("\n")
        )
      ]
    )

    result = described_class.new(path).call
    serialized = result.to_h.to_json

    expect(serialized).to include("[REDACTED]")
    expect(serialized).not_to include("system prompt")
    expect(serialized).not_to include("base_instructions")
    expect(serialized).not_to include("developer note")
    expect(serialized).not_to include("ciphertext")
    expect(serialized).not_to include("encrypted_content")
    expect(serialized).not_to include("abc123")
    expect(serialized).not_to include("sk-secret")
    expect(serialized).not_to include("quoted-secret")
    expect(result.timeline.last).to include(kind: "tool_output", truncated: true)
  end

  it "can skip timeline construction for inventory scans" do
    write_records(
      [
        response_item("message", "role" => "user", "content" => "Inventory title"),
        response_item("message", "role" => "assistant", "content" => "Inventory reply")
      ]
    )

    result = described_class.new(path, include_timeline: false).call

    expect(result.session[:title]).to eq("Inventory title")
    expect(result.counts).to include("user_messages" => 1, "assistant_messages" => 1)
    expect(result.timeline).to be_empty
  end

  it "keeps only the requested timeline slice while counting displayable items" do
    write_records(
      [
        response_item("message", "role" => "user", "content" => "First"),
        response_item("message", "role" => "assistant", "content" => "Second"),
        response_item("message", "role" => "user", "content" => "Third")
      ]
    )

    result = described_class.new(path, timeline_offset: 1, timeline_limit: 1).call

    expect(result.total_displayable).to eq(3)
    expect(result.timeline.sole).to include(kind: "assistant_message", text: "Second")
  end

  it "does not sanitize skipped tool payloads outside the requested timeline slice" do
    write_records(
      [
        response_item(
          "function_call_output",
          "call_id" => "call-1",
          "output" => "token=skipped-secret"
        ),
        response_item("message", "role" => "user", "content" => "Visible")
      ]
    )
    allow(CodexSessions::Redactor).to receive(:call).and_call_original

    result = described_class.new(path, timeline_offset: 1, timeline_limit: 1).call

    expect(result.total_displayable).to eq(2)
    expect(result.timeline.sole).to include(kind: "user_message", text: "Visible")
    expect(CodexSessions::Redactor).not_to have_received(:call).with("token=skipped-secret")
  end

  private

  def write_records(records)
    path.dirname.mkpath
    path.write(records.map(&:to_json).join("\n"))
  end

  def record(type, payload)
    {
      "timestamp" => "2026-07-10T10:00:00Z",
      "type" => type,
      "payload" => payload
    }
  end

  def response_item(item_type, payload)
    record("response_item", payload.merge("type" => item_type))
  end
end
