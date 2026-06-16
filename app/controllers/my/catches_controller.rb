module My
  class CatchesController < ApplicationController
    before_action :require_login

    def index
      redirect_to profile_path(current_user)
    end
  end
end
