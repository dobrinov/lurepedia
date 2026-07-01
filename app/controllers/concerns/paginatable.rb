module Paginatable
  Page = Struct.new(:records, :current, :total_pages, :total_count, :per, keyword_init: true) do
    def first? = current <= 1
    def last? = current >= total_pages
    def from = total_count.zero? ? 0 : ((current - 1) * per) + 1
    def to = [ current * per, total_count ].min
    def window
      (1..total_pages).to_a
    end
  end

  # Accepts a relation or a plain Array (for collections filtered in Ruby,
  # e.g. species matched on their locale-resolved common names).
  def paginate(scope, per: 12, param: :page)
    total = scope.is_a?(Array) ? scope.size : scope.count
    total = total.size if total.is_a?(Hash) # grouped counts
    total_pages = [ (total.to_f / per).ceil, 1 ].max
    current = params[param].to_i
    current = 1 if current < 1
    current = total_pages if current > total_pages
    records =
      if scope.is_a?(Array)
        scope[(current - 1) * per, per] || []
      else
        scope.limit(per).offset((current - 1) * per)
      end
    Page.new(records: records, current: current, total_pages: total_pages, total_count: total, per: per)
  end
end
