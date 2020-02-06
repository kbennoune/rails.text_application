require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'webmock/minitest'
require 'sidekiq/testing'
require 'minitest/mock'

Dir['test/**/test_helpers.rb'].each{|file| require Rails.root.join(file) }

Minitest::Reporters.use!([
  Minitest::Reporters::DefaultReporter.new,
  Minitest::Reporters::MeanTimeReporter.new
])

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  def setup
    super

    WebMock.enable!
    Sidekiq::Worker.clear_all
  end

  def teardown
    WebMock.disable!
  end
end
