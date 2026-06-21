class RegistrationsController < ApplicationController
  def new
    @user = User.new(country: "US", locale: I18n.locale.to_s)
  end

  def create
    @user = User.new(registration_params)
    @user.role = :member

    if @user.save
      start_new_session_for(@user)
      cookies[:locale] = @user.locale
      redirect_to after_authentication_url, notice: t("auth.welcome_back")
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation, :country, :locale)
  end
end
