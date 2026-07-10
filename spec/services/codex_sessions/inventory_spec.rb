# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe CodexSessions::Inventory do
  let(:root) { Pathname(Dir.mktmpdir) }

  after do
    FileUtils.remove_entry(root)
  end

  it "scans JSONL sessions and flags sessions from the current repository" do
    write_session("current.jsonl", "current-session", Rails.root.join("app").to_s)
    write_session("other.jsonl", "other-session", "/tmp/other")

    result = described_class.new(root:, current_repo: Rails.root.to_s).call

    expect(result.source).to include(
      root_path: root.to_s,
      scanned_count: 2,
      unreadable_count: 0,
      parse_errors: []
    )
    expect(result.sessions.find { |session| session[:id] == "current-session" }).to include(
      current_repo: true
    )
    expect(result.sessions.find { |session| session[:id] == "other-session" }).to include(
      current_repo: false
    )
  end

  it "reports parse errors in source metadata" do
    path = root.join("bad.jsonl")
    path.write("{bad json")

    result = described_class.new(root:).call

    expect(result.source.fetch(:scanned_count)).to eq(1)
    expect(result.source.fetch(:parse_errors).sole).to include(
      path: path.to_s,
      line: 1
    )
  end

  private

  def write_session(filename, session_id, cwd)
    root.join(filename).write(
      {
        "timestamp" => "2026-07-10T10:00:00Z",
        "type" => "session_meta",
        "payload" => {
          "session_id" => session_id,
          "cwd" => cwd
        }
      }.to_json
    )
  end
end
