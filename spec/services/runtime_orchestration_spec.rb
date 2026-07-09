# frozen_string_literal: true

require "rails_helper"

RSpec.describe RuntimeOrchestration::Supervisor do
  describe "#restart" do
    it "uses a driver-level restart when the placement driver supports it" do
      runtime_instance = create(:runtime_instance, status: "running")
      driver = instance_double(PlacementDrivers::DockerCompose)

      allow(PlacementDrivers).to receive(:for).with("docker_compose").and_return(driver)
      allow(driver).to receive(:restart).with(runtime_instance) do
        runtime_instance.update!(status: "running", last_heartbeat_at: Time.current)
      end

      described_class.new.restart(runtime_instance)

      expect(driver).to have_received(:restart).with(runtime_instance)
    end
  end
end
