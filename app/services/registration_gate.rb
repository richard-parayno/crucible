# frozen_string_literal: true

class RegistrationGate
  SETUP_TOKEN_ENV = "CRUCIBLE_SETUP_TOKEN"

  class << self
    def open?
      !User.exists?
    end

    def setup_token_required?
      open? && setup_token.present?
    end

    def allowed_setup_token?(token)
      return false unless open?
      return !Rails.env.production? if setup_token.blank?

      ActiveSupport::SecurityUtils.secure_compare(token.to_s, setup_token)
    end

    def setup_token
      ENV[SETUP_TOKEN_ENV].to_s
    end
  end
end
