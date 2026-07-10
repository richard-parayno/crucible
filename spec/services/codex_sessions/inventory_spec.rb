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
      route_id: Base64.urlsafe_encode64("current.jsonl", padding: false),
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

  it "paginates sessions after sorting by mtime descending" do
    older = write_session("older.jsonl", "older-session", "/tmp/older")
    newer = write_session("newer.jsonl", "newer-session", "/tmp/newer")
    File.utime(1.hour.ago.to_time, 1.hour.ago.to_time, older)
    File.utime(Time.current.to_time, Time.current.to_time, newer)

    result = described_class.new(root:, page: 1, per_page: 1).call

    expect(result.sessions.sole).to include(id: "newer-session")
    expect(result.pagination).to include(
      page: 1,
      per_page: 1,
      total_count: 2,
      total_pages: 2,
      has_previous_page: false,
      has_next_page: true
    )
    expect(result.source).to include(scanned_count: 2, parsed_count: 1)
  end

  it "caches summaries by file metadata" do
    cache_store = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(cache_store)
    write_session("cached.jsonl", "cached-session", Rails.root.to_s)

    first = described_class.new(root:).call
    second = described_class.new(root:).call

    expect(first.source.fetch(:cache)).to include(hits: 0, misses: 1)
    expect(second.source.fetch(:cache)).to include(hits: 1, misses: 0)
    expect(second.source).to include(parsed_count: 0)
  end

  it "resolves route ids without scanning unrelated summaries" do
    cache_store = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(cache_store)
    target = write_session("target.jsonl", "target-session", Rails.root.to_s)
    other = write_session("other.jsonl", "other-session", Rails.root.to_s)
    allow(CodexSessions::Parser).to receive(:new).and_call_original

    route_id = Base64.urlsafe_encode64("target.jsonl", padding: false)
    session = described_class.new(root:).find(route_id)

    expect(session).to include(id: "target-session")
    expect(CodexSessions::Parser).to have_received(:new).with(target, include_timeline: false).once
    expect(CodexSessions::Parser).not_to have_received(:new).with(other, include_timeline: false)
  end

  private

  def write_session(filename, session_id, cwd)
    path = root.join(filename)
    path.write(
      {
        "timestamp" => "2026-07-10T10:00:00Z",
        "type" => "session_meta",
        "payload" => {
          "session_id" => session_id,
          "cwd" => cwd
        }
      }.to_json
    )
    path
  end
end
