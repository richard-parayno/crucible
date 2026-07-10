# frozen_string_literal: true

require "rails_helper"

RSpec.describe "User default workspace", type: :model do
  it "creates a default workspace for each user" do
    user = create(:user)

    expect(user.default_workspace).to have_attributes(
      name: "Default workspace",
      default_workspace: true
    )
  end

  it "keeps only one default workspace per user" do
    user = create(:user)
    workspace = create(:workspace, user:, name: "Client project", default_workspace: true)

    expect(user.workspaces.default_workspace).to contain_exactly(workspace)
  end
end
