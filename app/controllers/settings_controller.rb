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

  # Set a password (OAuth-first users) or change an existing one. Kept separate
  # from #update so profile edits never carry password fields, and so we can
  # require the current password before allowing a change.
  def password
    @user = current_user

    if @user.password_set? && !@user.authenticate(params.dig(:user, :current_password).to_s)
      return password_error(t("settings.current_password_wrong"))
    end

    @user.assign_attributes(password_params)
    if @user.save(context: :password_update)
      redirect_to profile_path(@user, tab: "settings", locale: @user.locale), notice: t("settings.password_saved")
    else
      password_error(@user.errors.full_messages.to_sentence)
    end
  end

  private

  def password_error(message)
    @user = current_user
    flash.now[:alert] = message
    render :edit, status: :unprocessable_entity
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  # Which profile tab to return to after a save. The avatar can be changed from
  # the sidebar on any tab, so any public tab is a valid return target.
  def return_tab
    %w[catches favorites contributions settings].include?(params[:return_tab]) ? params[:return_tab] : "settings"
  end

  def settings_params
    params.require(:user).permit(:name, :bio, :country, :locale, :time_zone, :length_units, :weight_units, :depth_units, :username, :avatar)
  end
end
