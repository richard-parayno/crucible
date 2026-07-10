# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SystemChecks", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in_as(user)
    allow(HostCapabilities).to receive(:new).and_return(
      instance_double(HostCapabilities, call: {"container" => {"docker" => {"status" => "supported"}}})
    )
  end

  it "renders host and agent capability checks" do
    get system_check_path

    expect(response).to have_http_status(:success)
    expect(inertia).to be_inertia_response
    expect(inertia).to render_component("system_checks/show")
    expect(inertia.props.fetch("host_capabilities")).to eq("container" => {"docker" => {"status" => "supported"}})
    expect(inertia.props.fetch("runtime_definitions")).not_to be_empty
  end
end
