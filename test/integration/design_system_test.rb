require "test_helper"

# The design-system gallery renders the real shared partials from in-memory
# sample objects (no DB). This guards that those partials still render and that
# every tab is present.
class DesignSystemTest < ActionDispatch::IntegrationTest
  setup do
    get design_system_path
  end

  test "renders successfully" do
    assert_response :success
  end

  test "has all five top-level tabs" do
    %w[foundations buttons_forms indicators navigation components].each do |name|
      assert_select ".tab[data-tab-name=?]", name
      assert_select "[data-tab-panel=?]", name
    end
  end

  test "shows foundation tokens, buttons and forms" do
    assert_select ".ds-swatch", minimum: 5
    assert_select ".btn-primary"
    assert_select ".combobox"
    assert_select ".toggle"
  end

  test "renders data-coupled components from in-memory samples" do
    assert_select ".lure-card", minimum: 2 # proven + unproven
    assert_select ".catch-card"
    assert_select ".lb-table"
  end
end
