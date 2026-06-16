module DesignSystemHelper
  # Wraps a rendered example with a monospace caption (usually its CSS class).
  def ds_example(label, &block)
    tag.div(class: "ds-item") { capture(&block) + tag.div(label, class: "ds-label") }
  end

  # A color-token swatch: color block + human name + the CSS variable.
  def ds_swatch(name, css_var)
    tag.div(class: "ds-swatch") do
      tag.div("", class: "ds-swatch-color", style: "background: var(#{css_var})") +
        tag.div(name, class: "ds-swatch-name") +
        tag.div(css_var, class: "ds-label")
    end
  end

  def ds_section(title, &block)
    tag.section(class: "ds-section") { tag.h3(title) + capture(&block) }
  end
end
