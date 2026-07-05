class LureLinksController < ApplicationController
  before_action :require_login
  before_action -> { require_contribution(:catalog) }
  before_action :load_lure

  # Similar-lure links are catalog entries: created live, queued for review
  # unless an admin adds them. Deliberately narrower than can_add_directly? —
  # a link touches two brands, so a verified owner of one brand still goes
  # through review (see LureLink).
  def create
    other = Lure.find_by(slug: params[:similar_lure])
    return redirect_to edit_lure_path(@lure), alert: t("lure.similar_not_found") unless other

    link = LureLink.new(lure: @lure, related_lure: other)
    if link.save
      if current_user.admin?
        redirect_to edit_lure_path(@lure), notice: t("contribute.added")
      else
        ModerationItem.create!(subject: link, kind: :catalog, submitter: current_user)
        redirect_to edit_lure_path(@lure), notice: t("catch.submitted")
      end
    else
      redirect_to edit_lure_path(@lure), alert: link.errors.full_messages.to_sentence
    end
  end

  def destroy
    require_moderator
    LureLink.involving(@lure).find(params[:id]).destroy
    redirect_to edit_lure_path(@lure), notice: t("contribute.edit_saved")
  end

  # Upload-time proposals: fingerprint the picked photo and return the closest
  # published lures as JSON for the new-color form's suggestion checkboxes.
  def preview
    photo = params[:photo]
    return render json: [] unless photo.respond_to?(:tempfile)

    signature = ColorSignature.from_file(photo.tempfile.path)
    suggestions = SimilarLureSuggestions.new(signature, exclude_lure: @lure).results

    render json: suggestions.map { |s| suggestion_json(s[:lure], s[:score]) }
  end

  private

  def load_lure
    @lure = Lure.find_by!(slug: params[:lure_id])
  end

  def suggestion_json(lure, score)
    photo = lure.primary_variant&.photo
    {
      slug: lure.slug,
      title: lure.title,
      brand: lure.brand.name,
      photo_url: photo&.attached? ? url_for(photo.variant(resize_to_fill: [ 120, 120 ])) : nil,
      match_label: t("lure.similar_match", score: (score * 100).round)
    }
  end
end
