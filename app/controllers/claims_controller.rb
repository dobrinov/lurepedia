class ClaimsController < ApplicationController
  before_action :require_login
  before_action -> { require_contribution(:claims) }

  CLAIMABLES = { "brand" => Brand, "shop" => Shop }.freeze

  def new
    @type = params[:type]
    @claimable = find_claimable
    @claim = @claimable&.claim || @claimable&.build_claim(user: current_user, email: current_user.email_address)
  end

  def create
    @type = params.dig(:claim, :type)
    @claimable = find_claimable(@type)

    # One claim per listing: once somebody has asked, the page just shows that
    # claim's status. A rejected claim is re-opened from the moderation queue.
    if @claimable.claim
      redirect_to new_claim_path(type: @type, slug: @claimable.slug) and return
    end

    @claim = @claimable.build_claim(user: current_user, **claim_params)
    if @claim.save
      ModerationItem.create!(subject: @claim, kind: :claim, submitter: current_user, mod_actionable: false)
      redirect_to new_claim_path(type: @type, slug: @claimable.slug), notice: t("claim.submitted_title")
    else
      flash.now[:alert] = @claim.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def claim_params
    params.require(:claim).permit(:email, :message).to_h.symbolize_keys
  end

  def find_claimable(type = params[:type])
    return nil if type.blank? || params[:slug].blank?

    CLAIMABLES.fetch(type).find_by(slug: params[:slug])
  end
end
