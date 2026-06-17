class RevisionsController < ApplicationController
  # Edit history is public, so revision detail is too.
  def show
    @revision = Revision.includes(:user, :subject).find(params[:id])
  end
end
