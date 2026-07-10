# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users", type: :request do
  describe "GET /sign_up" do
    it "returns http success" do
      get sign_up_url
      expect(response).to have_http_status(:success)
    end

    it "requires the setup token when one is configured" do
      with_setup_token("setup-secret") do
        get sign_up_url
        expect(response).to redirect_to(sign_in_url)
        expect(flash[:alert]).to eq("Use the setup URL from the Crucible installer to create the first administrator account.")

        get sign_up_url(setup_token: "setup-secret")
        expect(response).to have_http_status(:success)
      end
    end

    it "closes registration after the first user exists" do
      create(:user)

      get sign_up_url
      expect(response).to redirect_to(sign_in_url)
      expect(flash[:alert]).to eq("Registration is closed. Sign in with the existing administrator account.")
    end
  end

  describe "POST /sign_up" do
    it "creates a new user and redirects to the root url" do
      expect { post sign_up_url, params: attributes_for(:user) }.to change(User, :count).by(1)

      expect(response).to redirect_to(dashboard_url)
    end

    it "rejects first-admin creation without the configured setup token" do
      with_setup_token("setup-secret") do
        expect { post sign_up_url, params: attributes_for(:user) }.not_to change(User, :count)

        expect(response).to redirect_to(sign_in_url)
      end
    end

    it "creates the first admin with the configured setup token" do
      with_setup_token("setup-secret") do
        user_params = attributes_for(:user).merge(setup_token: "setup-secret")

        expect { post sign_up_url, params: user_params }.to change(User, :count).by(1)
        expect(response).to redirect_to(dashboard_url)
      end
    end
  end

  def with_setup_token(token)
    previous = ENV["CRUCIBLE_SETUP_TOKEN"]
    ENV["CRUCIBLE_SETUP_TOKEN"] = token
    yield
  ensure
    ENV["CRUCIBLE_SETUP_TOKEN"] = previous
  end
end
