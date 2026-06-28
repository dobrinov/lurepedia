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
      ModerationItem.create!(subject: @variant, kind: :catalog, submitter: current_user)
      redirect_to edit_lure_path(@lure), notice: t("catch.submitted")
    else
      flash.now[:alert] = @variant.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    commit_edit(@variant, variant_params, "#{@lure.title} — #{@variant.name}", edit_lure_path(@lure))
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
    params.require(:variant).permit(:name, :best_for, :uv_glow, :photo)
  end
end
