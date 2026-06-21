class LuresController < ApplicationController
  before_action :require_login, only: %i[new create edit update]
  before_action -> { require_contribution(:catalog) }, only: %i[new create edit update]
  before_action :load_form_collections, only: %i[new create edit update]

  def index
    @filter = LureFilter.new(params)
    @page = paginate(@filter.results, per: 12)
    @lures = @page.records
  end

  def show
    @lure = Lure.includes(:brand, :lure_type, variants: { photo_attachment: :blob }).find_by!(slug: params[:id])
    @variants = @lure.variants.to_a
    @builds = @lure.builds.ordered.to_a
    @default_variant = @lure.default_variant
    @selected_variant = @variants.detect { |v| v.to_color_param == params[:color].to_s } || @default_variant
    @availability = VariantBuild.where(variant_id: @variants.map(&:id))
      .pluck(:variant_id, :build_id)
      .each_with_object(Hash.new { |h, k| h[k] = [] }) { |(v, b), acc| acc[v] << b }
    @catches = @lure.catches.includes(:user, :species, :build).recent.limit(8)
    @buy_links = @lure.buy_links.includes(:shop).sort_by { |b| b.shop.promoted? ? 0 : 1 }
    @tab = %w[caught variations buy history].include?(params[:tab].to_s) ? params[:tab] : "variations"
  end

  # JSON consumed by the variation-picker modal (lure page + catch form).
  def variations
    lure = Lure.includes(:builds, variants: { photo_attachment: :blob }).find_by!(slug: params[:id])
    availability = VariantBuild.where(variant_id: lure.variants.map(&:id)).pluck(:variant_id, :build_id)
      .each_with_object(Hash.new { |h, k| h[k] = [] }) { |(v, b), acc| acc[v] << b }

    render json: {
      lure: { slug: lure.slug, title: lure.title },
      colors: lure.variants.map { |v|
        {
          id: v.id, name: v.name, best_for: v.best_for, uv_glow: v.uv_glow,
          catches_count: v.catches_count, default: v.id == lure.default_variant&.id,
          photo_url: v.photo.attached? ? url_for(v.photo.variant(resize_to_fill: [ 160, 160 ])) : nil,
          build_ids: availability[v.id]
        }
      },
      builds: lure.builds.ordered.map { |b|
        {
          id: b.id, name: b.name, action: b.action,
          action_label: helpers.lure_action_label(b.action),
          length: helpers.fmt_size_mm(b.length_mm), weight: helpers.fmt_weight(b.weight_g),
          depth: helpers.fmt_depth(b.depth_min_cm, b.depth_max_cm)
        }
      }
    }
  end

  def new
    @lure = Lure.new
  end

  def create
    brand = Brand.find_by(id: params.dig(:lure, :brand_id))
    type = LureType.find_by(id: params.dig(:lure, :lure_type_id)) || LureType.first
    @lure = Lure.new(lure_params.merge(brand: brand, lure_type: type))

    if brand && @lure.save
      @lure.revisions.create!(user: current_user, summary: t("provenance.created"))
      if can_add_directly?(brand)
        redirect_to lure_path(@lure), notice: t("contribute.added")
      else
        ModerationItem.create!(subject: @lure, kind: :catalog, submitter: current_user)
        redirect_to lure_path(@lure), notice: t("catch.submitted")
      end
    else
      flash.now[:alert] = @lure.errors.full_messages.to_sentence.presence || t("brand.title")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @lure = Lure.find_by!(slug: params[:id])
    @variants = @lure.variants.to_a
    @builds = @lure.builds.ordered.to_a
  end

  def update
    @lure = Lure.find_by!(slug: params[:id])
    attrs = lure_params
    attrs[:brand_id] = params.dig(:lure, :brand_id) if params.dig(:lure, :brand_id).present?
    attrs[:lure_type_id] = params.dig(:lure, :lure_type_id) if params.dig(:lure, :lure_type_id).present?
    commit_edit(@lure, attrs, @lure.title, lure_path(@lure))
  end

  private

  def load_form_collections
    @brands = Brand.alpha
    @lure_types = LureType.all
  end

  def lure_params
    params.require(:lure).permit(:model, :blurb, :action_video_url, :default_variant_id)
  end
end
