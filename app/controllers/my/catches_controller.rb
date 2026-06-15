module My
  class CatchesController < ApplicationController
    before_action :require_login

    def index
      @catches = current_user.catches.includes(:species, variant: :lure).recent
      @total_upvotes = @catches.sum(&:upvotes_count)
    end
  end
end
