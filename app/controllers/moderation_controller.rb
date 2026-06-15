class ModerationController < ApplicationController
  before_action :require_moderator

  def index
    @filter = params[:filter].presence
    scope = ModerationItem.includes(:submitter, :subject).newest_first
    scope = scope.of_kind(@filter) if @filter && ModerationItem.kinds.key?(@filter)
    @items = scope
    @counts = ModerationItem.pending.group(:kind).count
    @pending_total = ModerationItem.pending.count
  end

  def update
    @item = ModerationItem.find(params[:id])
    raise Authorization::NotAuthorized unless @item.actionable_by?(current_user)

    notice =
      case params[:decision]
      when "approve" then @item.approve!(current_user); t("moderation.approved")
      when "reject" then @item.reject!(current_user); t("moderation.rejected")
      when "undo" then @item.undo!; t("moderation.undo")
      else t("common.save")
      end
    redirect_to moderation_index_path(filter: params[:filter]), notice: notice
  end
end
