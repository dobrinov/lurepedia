class ReportsController < ApplicationController
  before_action :require_login

  REPORTABLES = { "Catch" => Catch, "Lure" => Lure, "Comment" => Comment }.freeze

  def create
    klass = REPORTABLES.fetch(params[:reportable_type], Catch)
    reportable = klass.find(params[:reportable_id])
    report = Report.create!(reportable: reportable, user: current_user, reason: params.dig(:report, :reason), note: params.dig(:report, :note))
    ModerationItem.create!(subject: report, kind: :report, submitter: current_user)
    redirect_back fallback_location: localized_root_path, notice: t("report.submitted")
  end
end
