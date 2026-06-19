module ModerationHelper
  def moderation_title(item)
    subject = item.subject
    case subject
    when Catch
      "#{species_common_name(subject.species)} — #{subject.lure.title}"
    when Lure then subject.title
    when Variant, Build then "#{subject.lure.title} — #{subject.name}"
    when Brand, Shop then subject.name
    when Species then subject.common_name
    when Report
      "#{t("report.reason_#{subject.reason}")} — #{report_target_label(subject)}"
    when Claim
      "#{subject.kind.titleize}: #{subject.claimable.try(:name)}"
    else subject.class.name
    end
  end

  def report_target_label(report)
    target = report.reportable
    case target
    when Catch then "#{species_common_name(target.species)}"
    when Lure then target.title
    else target.class.name
    end
  end

  def moderation_kind_class(kind)
    "kind-#{kind}"
  end
end
