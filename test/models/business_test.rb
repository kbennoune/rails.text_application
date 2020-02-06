require 'test_helper'

class BusinessTest < ActiveSupport::TestCase
  test 'a business has a root channel' do
    business = Business.create!
    other_business = Business.create!

    root_channel = Channel.create! topic: ::Channel::ROOT_TOPIC, business: business

    assert_equal root_channel, business.root_channel

  end
end
