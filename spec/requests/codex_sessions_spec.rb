# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe "Codex sessions", type: :request do
  let(:user) { create(:user) }
  let(:root) { Pathname(Dir.mktmpdir) }

  before do
    sign_in_as(user)
    stub_const("ENV", ENV.to_hash.merge("CODEX_SESSIONS_ROOT" => root.to_s))
  end

  after do
    FileUtils.remove_entry(root)
  end

  it "renders the authenticated index from local JSONL sessions" do
    write_session(
      "rollout-2026-07-10T10-00-00-session-one.jsonl",
      session_id: "session-one",
      cwd: Rails.root.to_s,
      user_prompt: "Show my local sessions"
    )

    get codex_sessions_path

    expect(response).to have_http_status(:success)
    expect(inertia).to be_inertia_response
    expect(inertia).to render_component("codex_sessions/index")

    session = inertia.props.fetch("sessions").sole
    expect(session).to include(
      "id" => "session-one",
      "route_id" => Base64.urlsafe_encode64("rollout-2026-07-10T10-00-00-session-one.jsonl", padding: false),
      "title" => "Show my local sessions",
      "cwd" => Rails.root.to_s,
      "current_repo" => true
    )
    expect(inertia.props.fetch("source")).to include(
      "root_path" => root.to_s,
      "scanned_count" => 1,
      "parsed_count" => 1,
      "unreadable_count" => 0
    )
    expect(inertia.props.fetch("pagination")).to include(
      "page" => 1,
      "per_page" => 50,
      "total_count" => 1,
      "total_pages" => 1,
      "has_previous_page" => false,
      "has_next_page" => false
    )
  end

  it "paginates the session index" do
    older = write_session(
      "older.jsonl",
      session_id: "older-session",
      cwd: Rails.root.to_s,
      user_prompt: "Older session"
    )
    newer = write_session(
      "newer.jsonl",
      session_id: "newer-session",
      cwd: Rails.root.to_s,
      user_prompt: "Newer session"
    )
    File.utime(1.hour.ago.to_time, 1.hour.ago.to_time, older)
    File.utime(Time.current.to_time, Time.current.to_time, newer)

    get codex_sessions_path(page: 1, per_page: 1)

    expect(response).to have_http_status(:success)
    expect(inertia.props.fetch("sessions").sole).to include("id" => "newer-session")
    expect(inertia.props.fetch("pagination")).to include(
      "page" => 1,
      "per_page" => 1,
      "total_count" => 2,
      "total_pages" => 2,
      "has_next_page" => true
    )
    expect(inertia.props.fetch("source")).to include(
      "scanned_count" => 2,
      "parsed_count" => 1
    )
  end

  it "renders a sanitized read-only session timeline" do
    write_raw_session(
      "session-two.jsonl",
      [
        record(
          "session_meta",
          "session_id" => "session-two",
          "cwd" => Rails.root.to_s,
          "base_instructions" => "never show this",
          "cli_version" => "1.2.3"
        ),
        response_item(
          "message",
          "role" => "developer",
          "content" => [{"type" => "input_text", "text" => "hidden developer message"}]
        ),
        response_item(
          "reasoning",
          "summary" => [],
          "encrypted_content" => "ciphertext"
        ),
        response_item(
          "message",
          "role" => "user",
          "content" => [{"type" => "input_text", "text" => "Please inspect TOKEN=abc123 OPENAI_API_KEY=\"sk-secret\""}]
        ),
        response_item(
          "function_call",
          "name" => "shell",
          "call_id" => "call-1",
          "arguments" => {"password" => "super-secret", "cmd" => "echo ok"}.to_json
        ),
        response_item(
          "function_call_output",
          "call_id" => "call-1",
          "output" => "Authorization: Bearer abc123"
        )
      ]
    )

    get codex_session_path("session-two")

    expect(response).to have_http_status(:success)
    expect(inertia).to render_component("codex_sessions/show")

    serialized = inertia.props.to_json
    expect(serialized).to include("[REDACTED]")
    expect(serialized).not_to include("never show this")
    expect(serialized).not_to include("ciphertext")
    expect(serialized).not_to include("hidden developer message")
    expect(serialized).not_to include("super-secret")
    expect(serialized).not_to include("abc123")
    expect(serialized).not_to include("sk-secret")
  end

  it "does not expose malformed JSON contents through parse errors" do
    root.join("bad.jsonl").write(
      [
        record("session_meta", "session_id" => "bad-session").to_json,
        "{bad json token=super-secret"
      ].join("\n")
    )

    get codex_sessions_path

    serialized = inertia.props.to_json
    expect(serialized).to include("Malformed JSON record.")
    expect(serialized).not_to include("super-secret")
  end

  it "returns timeline chunks for the detail page" do
    write_raw_session(
      "chunked.jsonl",
      [
        record("session_meta", "session_id" => "chunked-session"),
        response_item("message", "role" => "user", "content" => "First"),
        response_item("message", "role" => "assistant", "content" => "Second"),
        response_item("message", "role" => "user", "content" => "Third")
      ]
    )

    route_id = Base64.urlsafe_encode64("chunked.jsonl", padding: false)
    get codex_session_path(route_id, timeline_offset: 1, timeline_limit: 1)

    expect(response).to have_http_status(:success)
    expect(inertia.props.fetch("timeline").sole).to include(
      "kind" => "assistant_message",
      "text" => "Second"
    )
    expect(inertia.props.fetch("timeline_page")).to include(
      "offset" => 1,
      "limit" => 1,
      "returned_count" => 1,
      "total_displayable" => 3,
      "has_next_page" => true
    )
  end

  it "returns not found for an unknown session" do
    get codex_session_path("missing")

    expect(response).to have_http_status(:not_found)
  end

  private

  def write_session(filename, session_id:, cwd:, user_prompt:)
    write_raw_session(
      filename,
      [
        record(
          "session_meta",
          "session_id" => session_id,
          "cwd" => cwd,
          "timestamp" => "2026-07-10T10:00:00Z",
          "cli_version" => "1.0.0",
          "source" => "codex_cli",
          "originator" => "codex"
        ),
        record("turn_context", "turn_id" => "turn-1", "cwd" => cwd),
        response_item(
          "message",
          "role" => "user",
          "content" => [{"type" => "input_text", "text" => user_prompt}]
        )
      ]
    )
  end

  def write_raw_session(filename, records)
    path = root.join(filename)
    path.dirname.mkpath
    path.write(records.map(&:to_json).join("\n"))
    path
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
