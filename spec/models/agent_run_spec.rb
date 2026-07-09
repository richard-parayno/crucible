# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentRun, type: :model do
  it "defaults to queued" do
    agent_run = build(:agent_run, status: nil)

    expect(agent_run).to be_valid
    expect(agent_run.status).to eq("queued")
  end

  it "requires an executable command" do
    agent_run = build(:agent_run, command: "")

    expect(agent_run).not_to be_valid
    expect(agent_run.errors[:command]).to be_present
  end
end
