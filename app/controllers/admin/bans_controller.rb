module Admin
  class BansController < ApplicationController
    before_action :require_admin
    before_action :set_user

    def index
      @bans = @user.bans.newest_first
      @ban = Ban.new
    end

    def create
      @ban = @user.bans.new(ban_attrs)
      @ban.issued_by = current_user
      if @ban.save
        redirect_to admin_user_bans_path(@user), notice: t("bans.admin.created")
      else
        @bans = @user.bans.newest_first
        flash.now[:alert] = @ban.errors.full_messages.to_sentence
        render :index, status: :unprocessable_entity
      end
    end

    def revoke
      ban = @user.bans.find(params[:id])
      ban.update!(revoked_at: Time.current, revoked_by: current_user)
      redirect_to admin_user_bans_path(@user), notice: t("bans.admin.revoked")
    end

    private

    def set_user
      @user = User.find_by_handle!(params[:user_id])
    end

    # Capabilities come from a preset (if chosen) or explicit checkboxes.
    def ban_attrs
      raw = params.require(:ban).permit(:reason, :expires_at, :preset, capabilities: [])
      preset = raw.delete(:preset)
      caps = Array(raw[:capabilities]).reject(&:blank?)
      caps = Ban::PRESETS.fetch(preset) if preset.present? && Ban::PRESETS.key?(preset)
      raw[:capabilities] = caps
      raw[:expires_at] = raw[:expires_at].presence
      raw
    end
  end
end
