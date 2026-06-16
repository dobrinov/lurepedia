class UpvotesController < ApplicationController
  before_action :require_login
  before_action -> { require_contribution(:upvotes) }

  def create
    @catch = Catch.find(params[:catch_id])
    Upvote.find_or_create_by!(user: current_user, catch: @catch)
    redirect_to catch_path(@catch)
  end

  def destroy
    @catch = Catch.find(params[:catch_id])
    Upvote.where(user: current_user, catch: @catch).destroy_all
    redirect_to catch_path(@catch)
  end
end
