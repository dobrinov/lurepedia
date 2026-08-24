require "test_helper"

class PaginatablePageTest < ActiveSupport::TestCase
  def page_numbers(current:, total_pages:)
    Paginatable::Page.new(current: current, total_pages: total_pages).page_numbers
  end

  test "few pages: no ellipsis, every page listed" do
    assert_equal [ 1, 2, 3 ], page_numbers(current: 1, total_pages: 3)
    assert_equal [ 1, 2 ], page_numbers(current: 2, total_pages: 2)
    assert_equal [ 1 ], page_numbers(current: 1, total_pages: 1)
  end

  test "current page near the start has one trailing gap" do
    assert_equal [ 1, 2, 3, nil, 44 ], page_numbers(current: 1, total_pages: 44)
  end

  test "current page in the middle has a gap on both sides" do
    assert_equal [ 1, nil, 5, 6, 7, 8, 9, nil, 44 ], page_numbers(current: 7, total_pages: 44)
  end

  test "current page near the end has one leading gap" do
    assert_equal [ 1, nil, 41, 42, 43, 44 ], page_numbers(current: 43, total_pages: 44)
  end

  test "window edge does not touch 1 or total_pages: no spurious adjacent gap" do
    # current=4 with window 2 covers 2..6, which abuts 1 directly (diff 1) — no ellipsis.
    assert_equal [ 1, 2, 3, 4, 5, 6, nil, 44 ], page_numbers(current: 4, total_pages: 44)
  end
end
