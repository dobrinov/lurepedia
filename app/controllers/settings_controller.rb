class SettingsController < ApplicationController
  before_action :require_login

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    @user.avatar.purge_later if params.dig(:user, :remove_avatar) == "1"
    if @user.update(settings_params)
      cookies[:locale] = @user.locale
      redirect_to profile_path(@user, tab: return_tab, locale: @user.locale), notice: t("settings.saved")
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Which profile tab to return to after a save. The avatar can be changed from
  # the sidebar on any tab, so any public tab is a valid return target.
  def return_tab
    %w[catches favorites contributions settings].include?(params[:return_tab]) ? params[:return_tab] : "settings"
  end

  def settings_params
    params.require(:user).permit(:name, :bio, :country, :locale, :time_zone, :length_units, :weight_units, :depth_units, :username, :avatar)
  end
end
