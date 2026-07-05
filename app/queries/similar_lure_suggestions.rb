# Ranks published lures by how closely their colors' photos match a given
# ColorSignature — the engine behind the "looks similar to…" proposals shown
# while a contributor uploads a new color. Candidate signatures come from blob
# metadata (written by TileBackgroundAnalyzer); a lure's score is its best
# match across all of its published colors.
#
# This is a suggestion engine only: nothing is linked without the contributor
# explicitly ticking a proposal.
class SimilarLureSuggestions
  THRESHOLD = 0.5 # histogram-intersection score below which a match reads as noise
  LIMIT = 4

  def initialize(signature, exclude_lure: nil)
    @signature = signature
    @exclude_lure = exclude_lure
  end

  # [ { lure:, score: } ] best-first. Empty without a usable signature.
  def results
    return [] unless @signature

    top = best_score_per_lure.select { |_id, score| score >= THRESHOLD }
                             .sort_by { |_id, score| -score }
                             .first(LIMIT)
    lures = Lure.published.where(id: top.map(&:first))
                .includes(:brand, :default_variant, variants: { photo_attachment: :blob })
                .index_by(&:id)
    top.filter_map { |id, score| { lure: lures[id], score: score } if lures[id] }
  end

  private

  def best_score_per_lure
    candidate_rows.each_with_object({}) do |(lure_id, metadata_json), best|
      candidate = ColorSignature.parse(parse_metadata(metadata_json)["color_signature"])
      next unless candidate

      score = @signature.similarity(candidate)
      best[lure_id] = score if score > best.fetch(lure_id, 0)
    end
  end

  # (lure_id, raw blob metadata) for every published color with a photo. The
  # catalog is small enough to score in Ruby; revisit if it grows past tens of
  # thousands of variants.
  def candidate_rows
    scope = Variant.published.joins(photo_attachment: :blob)
    scope = scope.where.not(lure_id: @exclude_lure.id) if @exclude_lure
    scope.pluck(:lure_id, "active_storage_blobs.metadata")
  end

  # Pluck deserializes the blob's store column into a Hash on this Rails
  # version; tolerate raw JSON text too so a coder change can't break scoring.
  def parse_metadata(raw)
    return raw if raw.is_a?(Hash)

    JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end
end
