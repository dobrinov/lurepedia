module Editable
  extend ActiveSupport::Concern

  included do
    helper_method :edit_affordance_label
  end

  private

  # Admins edit directly (no review); everyone else files a reviewed suggestion.
  def commit_edit(record, attrs, name, redirect_path)
    return unless require_contribution(:catalog)

    changeset = build_changeset(record, attrs)

    if current_user&.admin?
      if record.update(attrs)
        record.revisions.create!(user: current_user, summary: "Edited #{name}", changeset: changeset)
        redirect_to redirect_path, notice: t("contribute.edit_saved")
      else
        flash.now[:alert] = record.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    else
      revision = record.revisions.create!(user: current_user, summary: "Suggested an edit to #{name}", changeset: changeset)
      ModerationItem.create!(subject: record, kind: :edit, submitter: current_user, revision: revision)
      redirect_to redirect_path, notice: t("contribute.suggested")
    end
  end

  # Field-level before/after map for the proposed attrs, keyed by attribute:
  # { "field" => [ old_value, new_value ] }. Only genuinely changed fields are
  # kept, and values are cast to the column's type so a "100" param compares
  # equal to an integer 100.
  def build_changeset(record, attrs)
    attrs.to_h.each_with_object({}) do |(key, value), diff|
      next unless record.respond_to?(key)

      if key.to_s.end_with?("_ids")
        old_value = Array(record.public_send(key)).map(&:to_i).sort
        new_value = Array(value).reject(&:blank?).map(&:to_i).sort
      else
        type = record.class.type_for_attribute(key.to_s)
        old_value = record.public_send(key)
        new_value = type ? type.cast(value) : value
      end
      diff[key.to_s] = [ old_value, new_value ] unless old_value == new_value
    end
  end

  # Label shown on edit affordances: admins "Edit", others "Suggest an edit".
  def edit_affordance_label
    current_user&.admin? ? t("common.edit") : t("contribute.suggest_edit")
  end
end
