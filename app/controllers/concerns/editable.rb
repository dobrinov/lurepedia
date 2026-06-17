module Editable
  extend ActiveSupport::Concern

  included do
    helper_method :edit_affordance_label
  end

  private

  # Admins edit directly (no review); everyone else files a reviewed suggestion.
  def commit_edit(record, attrs, name, redirect_path)
    return unless require_contribution(:catalog)

    if current_user&.admin?
      if record.update(attrs)
        record.revisions.create!(user: current_user, summary: "Edited #{name}")
        redirect_to redirect_path, notice: t("contribute.edit_saved")
      else
        flash.now[:alert] = record.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    else
      record.revisions.create!(user: current_user, summary: "Suggested an edit to #{name}")
      ModerationItem.create!(subject: record, kind: :edit, submitter: current_user)
      redirect_to redirect_path, notice: t("contribute.suggested")
    end
  end

  # Label shown on edit affordances: admins "Edit", others "Suggest an edit".
  def edit_affordance_label
    current_user&.admin? ? t("common.edit") : t("contribute.suggest_edit")
  end
end
