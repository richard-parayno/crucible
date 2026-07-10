# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SystemChecks", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in_as(user)
    allow(HostCapabilities).to receive(:new).and_return(
      instance_double(HostCapabilities, call: {"container" => {"docker" => {"status" => "supported"}}})
    )
    allow(AgentRuntimeInventory).to receive(:new).and_return(
      instance_double(
        AgentRuntimeInventory,
        call: {
          detected_runtimes: [{id: "detected:codex"}],
          host_processes: [{id: "host_process:123"}],
          manual_runtimes: [{id: "runtime_instance:456"}]
        }
      )
    )
  end

  it "renders host and agent capability checks" do
    get system_check_path

    expect(response).to have_http_status(:success)
    expect(inertia).to be_inertia_response
    expect(inertia).to render_component("system_checks/show")
    expect(inertia.props.fetch("host_capabilities")).to eq("container" => {"docker" => {"status" => "supported"}})
    expect(inertia.props.fetch("installed_binaries")).to eq([{"id" => "detected:codex"}])
    expect(inertia.props.fetch("host_processes")).to eq([{"id" => "host_process:123"}])
    expect(inertia.props.fetch("managed_runtimes")).to eq([{"id" => "runtime_instance:456"}])
    expect(inertia.props.fetch("runtime_definitions").pluck("kind")).to eq(%w[codex claude opencode hermes openclaw])
    expect(inertia.props.fetch("runtime_definitions").first.fetch("metadata")).to include(
      "install_sources" => be_present,
      "trusted_urls" => be_present,
      "version_pin" => include("field" => "npm_package_version"),
      "verified_artifacts" => include(hash_including("kind" => "integrity", "value" => "npm registry dist.integrity"))
    )
  end
end
