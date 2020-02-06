require 'test_helper'

class TextGroupTest < ActiveSupport::TestCase
  def business
    @business ||= Business.create! name: 'A business'
  end

  def root_channel
    @root_channel ||= ::Channel.create topic: ::Channel::ROOT_TOPIC, business: business
  end

  def around(&test)
    UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
      test.call
    end
  end

  test "mention_code is a simplified name" do
    kitchen_group = TextGroup.create! name: 'kitchen group', business: root_channel.business
    assert_equal '@kitchen', kitchen_group.mention_code(within: root_channel)
  end

  test 'name when there is a similar code with dashes' do
    other_group = TextGroup.create! name: 'a kitchen group', business: root_channel.business
    kitchen_group = TextGroup.create! name: 'a-kitchen-group', business: root_channel.business

    assert_equal '@a-kitchen-group', kitchen_group.mention_code(within: root_channel)
  end

  test 'name when there is a similar code with a different name' do
    other_group = TextGroup.create! name: 'kitchen group main', business: root_channel.business
    kitchen_group = TextGroup.create! name: 'kitchen group alternate', business: root_channel.business

    assert_equal '@kitchengroupalternate', kitchen_group.mention_code(within: root_channel)
  end
end
