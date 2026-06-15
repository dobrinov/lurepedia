module Admin
  class UsersController < ApplicationController
    before_action :require_admin

    def update
      @user = User.find(params[:id])
      @user.update!(role: params.dig(:user, :role))
      redirect_to admin_people_path, notice: t("settings.saved")
    end
  end
end
