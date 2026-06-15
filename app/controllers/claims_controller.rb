class ClaimsController < ApplicationController
  before_action :require_login

  CLAIMABLES = { "brand" => Brand, "shop" => Shop }.freeze

  def new
    @type = params[:type]
    @claimable = find_claimable
    @claim = @claimable&.claim || @claimable&.build_claim(user: current_user, email: current_user.email_address)
  end

  def create
    @claimable = find_claimable(params.dig(:claim, :type))
    @claim = @claimable.claim || @claimable.build_claim
    @claim.assign_attributes(user: current_user, email: params.dig(:claim, :email))
    @claim.save!
    redirect_to new_claim_path(type: claim_type(@claimable), slug: @claimable.slug), notice: t("claim.step_dns")
  end

  def verify
    @claim = Claim.find(params[:id])
    @claim.verify!
    ModerationItem.find_or_create_by!(subject: @claim, kind: :claim) do |m|
      m.submitter = current_user
      m.mod_actionable = false
    end
    redirect_to new_claim_path(type: @claim.kind, slug: @claim.claimable.slug), notice: t("claim.verified_title")
  end

  private

  def find_claimable(type = params[:type])
    return nil if type.blank? || params[:slug].blank?

    CLAIMABLES.fetch(type).find_by(slug: params[:slug])
  end

  def claim_type(claimable)
    claimable.class.name.downcase
  end
end
