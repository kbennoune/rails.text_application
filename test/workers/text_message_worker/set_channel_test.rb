require 'test_helper'

module TextMessageWorker
  class SetChannelTest < ActiveSupport::TestCase
    def people
      @people ||= begin
        3.times.map do |n|
          Person.new( mobile: people_phone_numbers[n] ).tap do |person|
            person.channel_people.build(
              application_phone_number: ApplicationPhoneNumber.create( number: app_phone_numbers[n] ),
              channel: root_channel
            )

            person.tap(&:save!)
          end
        end
      end
    end

    def people_phone_numbers
      [
        PhoneNumber.new('(919) 555-9999'),
        PhoneNumber.new('(919) 555-0000'),
        PhoneNumber.new('(919) 555-0001')
      ]
    end

    def app_phone_numbers
      [
        PhoneNumber.new('(313) 999-9999'),
        PhoneNumber.new('(313) 999-0000'),
        PhoneNumber.new('(313) 999-0001')
      ]
    end

    def root_channel
      @root_channel ||= Channel.new( business: Business.new ).tap(&:save!)
    end

    def text_message_from(person, channel_person: nil)
      channel_person ||= person.channel_people[0]
      app_phone_number = channel_person.channel_phone_number
      mobile_phone_number = person.mobile

      TextMessage.create! to: app_phone_number, message_from: mobile_phone_number
    end

    test 'assigns a channel to the text message' do
      people.each do |texter|
        worker = TextMessageWorker::SetChannel.new
        text_message = text_message_from(texter)
        worker.perform( text_message.id )
        assert_equal root_channel.id, text_message.reload.channel.id
      end
    end

    test 'assigns a channel for an alias' do
      mobile_number = '9195556789'
      alias_person = Person.create!
      real_person = Person.create! mobile: mobile_number, aliases: [ alias_person ]

      chat_channel = ::Channel.create business: root_channel.business, topic: ::Channel::CHAT_TOPIC, people: [ alias_person ]

      worker = TextMessageWorker::SetChannel.new
      text_message = text_message_from( real_person, channel_person: alias_person.channel_people.first )
      worker.perform( text_message.id )
      assert_equal chat_channel, text_message.reload.channel
    end

    test 'assigns a person the text message' do
      people.each do |texter|
        worker = TextMessageWorker::SetChannel.new
        text_message = text_message_from(texter)
        worker.perform( text_message.id )
        assert_equal text_message.reload.sender_id, texter.id
      end
    end

    test 'assigns a person for an alias' do
      mobile_number = '9195556789'
      alias_person = Person.create!
      real_person = Person.create! mobile: mobile_number, aliases: [ alias_person ]

      chat_channel = ::Channel.create business: root_channel.business, topic: ::Channel::CHAT_TOPIC, people: [ alias_person ]

      worker = TextMessageWorker::SetChannel.new
      text_message = text_message_from( real_person, channel_person: alias_person.channel_people.first )
      worker.perform( text_message.id )
      assert_equal text_message.reload.sender_id, real_person.id
    end
  end
end
