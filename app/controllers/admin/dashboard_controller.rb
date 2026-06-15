module Admin
  class DashboardController < ApplicationController
    before_action :require_admin

    def overview
      @pending_by_kind = ModerationItem.pending.group(:kind).count
      @pending_total = ModerationItem.pending.count
      @catches_count = Catch.count
      @contributors = User.count
      @lures_count = Lure.count
    end

    def people
      @users = User.order(:role => :desc, :name => :asc)
    end

    def activity
      @revisions = Revision.includes(:user, :subject).newest_first.limit(50)
    end
  end
end
