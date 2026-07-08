class VariantsController < ApplicationController
  before_action :require_login
  before_action -> { require_contribution(:catalog) }
  before_action :load_lure
  before_action :load_variant, only: %i[edit update destroy]

  def new
    @variant = @lure.variants.new
  end

  # New colors are catalog entries: created immediately but queued for review,
  # mirroring LuresController#create.
  def create
    @variant = @lure.variants.new(variant_params)

    if @variant.save
      @variant.revisions.create!(user: current_user, summary: t("provenance.created"))
      link_similar_lures
      if can_add_directly?(owning_brand(@variant))
        redirect_to edit_lure_path(@lure), notice: t("contribute.added")
      else
        ModerationItem.create!(subject: @variant, kind: :catalog, submitter: current_user)
        redirect_to edit_lure_path(@lure), notice: t("catch.submitted")
      end
    else
      flash.now[:alert] = @variant.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    saved = commit_edit(@variant, variant_params, "#{@lure.title} — #{@variant.name}", edit_lure_path(@lure))
    propagate_bg_color_to_siblings if saved && propagate_bg_color?
  end

  def destroy
    require_moderator
    @variant.destroy
    redirect_to edit_lure_path(@lure), notice: t("contribute.edit_saved")
  end

  private

  def load_lure
    @lure = Lure.find_by!(slug: params[:lure_id])
  end

  def load_variant
    @variant = @lure.variants.find(params[:id])
  end

  def variant_params
    permitted = params.require(:variant).permit(:name, :best_for, :glow, :uv, :photo,
                                    :photo_crop_x, :photo_crop_y, :photo_crop_w, :photo_crop_h, :photo_bg_color,
                                    build_ids: [])
    permitted[:build_ids] = permitted[:build_ids].reject(&:blank?) if permitted[:build_ids]
    permitted
  end

  # Cross-references ticked in the upload form's "looks similar" proposals.
  # Links are catalog entries queued for review unless the contributor is an
  # admin — mirroring LureLinksController#create, and deliberately narrower
  # than the can_add_directly? gate used for the color itself (see LureLink).
  def link_similar_lures
    Lure.where(slug: Array(params[:similar_lure_slugs]).reject(&:blank?)).find_each do |other|
      link = LureLink.new(lure: @lure, related_lure: other)
      next unless link.save

      ModerationItem.create!(subject: link, kind: :catalog, submitter: current_user) unless current_user.admin?
    end
  end

  # "Apply the background to all colors" is offered only to direct editors
  # (admins, verified brand owners) — a member checking it would otherwise
  # spawn a moderation item per sibling color.
  def propagate_bg_color?
    params[:apply_bg_to_all].present? && can_edit_directly?(@variant)
  end

  # Copy this color's tile background to the lure's other colors, with a
  # revision per changed sibling so the propagation shows up in history.
  def propagate_bg_color_to_siblings
    color = variant_params[:photo_bg_color].presence
    @lure.variants.where.not(id: @variant.id).find_each do |sibling|
      next if sibling.photo_bg_color == color

      changeset = { "photo_bg_color" => [ sibling.photo_bg_color, color ] }
      sibling.update!(photo_bg_color: color)
      sibling.revisions.create!(user: current_user, summary: "Edited #{@lure.title} — #{sibling.name}", changeset: changeset)
    end
  end
end
