class BuildsController < ApplicationController
  before_action :require_login
  before_action -> { require_contribution(:catalog) }
  before_action :load_lure
  before_action :load_build, only: %i[edit update destroy]

  def new
    @build = @lure.builds.new
  end

  # New builds are catalog entries: created immediately but queued for review,
  # mirroring LuresController#create.
  def create
    @build = @lure.builds.new(build_params)

    if @build.save
      @build.revisions.create!(user: current_user, summary: t("provenance.created"))
      if can_add_directly?(owning_brand(@build))
        redirect_to edit_lure_path(@lure), notice: t("contribute.added")
      else
        ModerationItem.create!(subject: @build, kind: :catalog, submitter: current_user)
        redirect_to edit_lure_path(@lure), notice: t("catch.submitted")
      end
    else
      flash.now[:alert] = @build.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    commit_edit(@build, build_params, "#{@lure.title} — #{@build.name}", edit_lure_path(@lure))
  end

  def destroy
    require_moderator
    @build.destroy
    redirect_to edit_lure_path(@lure), notice: t("contribute.edit_saved")
  end

  private

  def load_lure
    @lure = Lure.find_by!(slug: params[:lure_id])
  end

  def load_build
    @build = @lure.builds.find(params[:id])
  end

  def build_params
    permitted = params.require(:build).permit(:name, :length_mm, :weight_g, :depth_min_cm, :depth_max_cm, :action, :water, :hook_type)
    # The blank "unknown" hook choice submits "", which the enum can't accept — store it as nil.
    permitted[:hook_type] = permitted[:hook_type].presence if permitted.key?(:hook_type)
    permitted
  end
end
