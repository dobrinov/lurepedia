# Living styleguide: a public, tabbed gallery of the app's UI elements rendered
# from in-memory sample objects (see DesignSystem::SampleData).
class DesignSystemController < ApplicationController
  def index
    @samples = DesignSystem::SampleData.new
  end
end
