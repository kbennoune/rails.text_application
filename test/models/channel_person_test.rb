require 'test_helper'

class ChannelPersonTest < ActiveSupport::TestCase
  def person
    @person ||= Person.create!
  end

  def root_channel
    @root_channel ||= ::Channel.create!(business: Business.new, topic: ::Channel::ROOT_TOPIC)
  end

  def chat_channel
    @chat_channel ||= ::Channel.create!(business: root_channel.business, topic: ::Channel::CHAT_TOPIC)
  end

  test 'root_channel_phone_number' do
    root_channel_person = ChannelPerson.create! person: person, channel: root_channel
    chat_channel_person = ChannelPerson.create! person: person, channel: chat_channel

    assert_equal root_channel_person.application_phone_number.number, chat_channel_person.root_application_phone_number
    assert_equal root_channel_person.application_phone_number.number, root_channel_person.root_application_phone_number

  end
end
