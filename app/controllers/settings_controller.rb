class SettingsController < ApplicationController
  before_action :require_login

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(settings_params)
      cookies[:locale] = @user.locale
      redirect_to edit_settings_path(locale: @user.locale), notice: t("settings.saved")
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:user).permit(:name, :bio, :country, :locale, :units, :username)
  end
end
