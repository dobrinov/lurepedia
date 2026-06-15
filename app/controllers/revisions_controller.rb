class RevisionsController < ApplicationController
  before_action :require_login

  SUBJECTS = { "lure" => Lure, "brand" => Brand, "shop" => Shop, "species" => Species }.freeze

  def new
    @subject = find_subject
    @type = params[:type]
  end

  def create
    @subject = find_subject(params.dig(:revision, :type))
    summary = params.dig(:revision, :summary).presence || t("contribute.suggest_edit")
    @subject.revisions.create!(user: current_user, summary: summary)
    item = ModerationItem.create!(subject: @subject, kind: :edit, submitter: current_user)
    redirect_to subject_path(@subject), notice: t("contribute.suggested")
  end

  private

  def find_subject(type = params[:type])
    klass = SUBJECTS.fetch(type)
    klass.find_by!(slug: params[:slug] || params.dig(:revision, :slug))
  end

  def subject_path(subject)
    case subject
    when Lure then lure_path(subject)
    when Brand then brand_path(subject)
    when Shop then shops_path
    when Species then species_path(subject)
    else localized_root_path
    end
  end
end
