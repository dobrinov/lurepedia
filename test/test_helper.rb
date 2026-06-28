ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Ensure a lure has a build (catches require a color + a build).
    def ensure_build(lure, **attrs)
      lure.builds.first || lure.builds.create!({ name: "Standard" }.merge(attrs))
    end

    # Create a catch against a color, defaulting the build to the lure's standard
    # one (both belong to the same lure, as the catch validation requires).
    def create_catch(variant:, species:, user:, build: nil, **attrs)
      build ||= ensure_build(variant.lure)
      Catch.create!(user: user, variant: variant, build: build, species: species, **attrs)
    end
  end
end
