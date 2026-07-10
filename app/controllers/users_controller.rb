# frozen_string_literal: true

class UsersController < InertiaController
  skip_before_action :authenticate, only: %i[new create]
  before_action :require_no_authentication, only: %i[new create]
  before_action :require_registration_open, only: %i[new create]
  before_action :require_setup_token, only: %i[new create]

  def new
    @user = User.new
    render inertia: {setup_token: params[:setup_token].to_s}
  end

  def create
    @user = User.new(user_params)

    if @user.save
      session_record = @user.sessions.create!
      cookies.signed.permanent[:session_token] = {value: session_record.id, httponly: true}

      send_email_verification
      redirect_to dashboard_path, notice: "Welcome! You have signed up successfully"
    else
      redirect_to sign_up_path, inertia: {errors: @user.errors}
    end
  end

  def destroy
    user = Current.user
    if user.authenticate(params[:password_challenge] || "")
      user.destroy!
      Current.session = nil
      redirect_to root_path, notice: "Your account has been deleted", inertia: {clear_history: true}
    else
      redirect_to settings_profile_path, inertia: {errors: {password_challenge: "Password challenge is invalid"}}
    end
  end

  private

  def require_registration_open
    return if RegistrationGate.open?

    redirect_to sign_in_path, alert: "Registration is closed. Sign in with the existing administrator account."
  end

  def require_setup_token
    return if RegistrationGate.allowed_setup_token?(params[:setup_token])

    redirect_to sign_in_path, alert: "Use the setup URL from the Crucible installer to create the first administrator account."
  end

  def user_params
    params.permit(:email, :name, :password, :password_confirmation)
  end

  def send_email_verification
    UserMailer.with(user: @user).email_verification.deliver_later
  end
end
