class SearchController < ApplicationController
  def index
    @q = params[:q].to_s.strip
    if @q.present?
      like = "%#{@q.downcase}%"
      @lures = Lure.published.joins(:brand).where("LOWER(lures.model) LIKE :q OR LOWER(brands.name) LIKE :q", q: like).includes(:brand, :lure_type).limit(24)
      @brands = Brand.published.where("LOWER(name) LIKE ?", like).limit(24)
      @species = Species.published.select { |s| s.common_name.downcase.include?(@q.downcase) }
    else
      @lures = []
      @brands = []
      @species = []
    end
  end
end
