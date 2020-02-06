require 'test_helper'

module ApiActions
  module Channel
    class StartTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def around(&test)
        UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
          test.call
        end
      end

      def sender
        @sender ||= ::Person.create!( name: 'Jaim Waler', mobile: '2133334444' )
      end

      def people
        @people ||= begin
          [
            ::Person.create!( name: 'Shirley Eastman' ),
            ::Person.create!( name: 'Amal King' ),
            ::Person.create!( name: 'Mervin Nesbit' ),
            ::Person.create!( name: 'Karen Strong-Smith' )
          ].each{|person|
            root_channel.channel_people << ChannelPerson.new( person_id: person.id, application_phone_number: ApplicationPhoneNumber.new(number: '01121321393610') )
          }
        end
      end

      test 'it will create text messages for a single recipient' do
        included_recipients = [ people[1] ]
        new_channel = ::Channel.new( topic: ::Channel::CHAT_TOPIC, business: root_channel.business, started_by_person: sender, text_groups: [] )
        message = "Hey, is this an outgoing message?\nI think it is..."
        action = ::ApiActions::Channel::Start.new( sender, sender.mobile, included_recipients, new_channel, message )

        action.call
        assert new_channel.persisted?
        assert_equal 2, new_channel.text_messages.size
      end

      test 'it will create a header addendum for the outgoing message' do
        included_recipients = [ people[0] ]
        new_channel = ::Channel.new( topic: ::Channel::CHAT_TOPIC, business: root_channel.business, started_by_person: sender, text_groups: [] )
        message = "Hey, is this an outgoing message?\nI think it is..."
        action = ::ApiActions::Channel::Start.new( sender, sender.mobile, included_recipients, new_channel, message )

        action.call
        sender_message = new_channel.text_messages.find{|tm| tm.to && tm.to.include?(sender.mobile) }
        general_messages = new_channel.text_messages - [ sender_message ]

        assert general_messages.all?{|m| m.header_addendum_key.present? }
      end

      test 'the header addendum will end up in the final message' do
        included_recipients = [ people[0] ]
        new_channel = ::Channel.new( topic: ::Channel::CHAT_TOPIC, business: root_channel.business, started_by_person: sender, text_groups: [] )
        message = "Hey, is this an outgoing message?\nI think it is..."
        action = ::ApiActions::Channel::Start.new( sender, sender.mobile, included_recipients, new_channel, message )

        action.call
        general_messages = new_channel.text_messages.find_all{|tm| tm.to.blank? }

        generator = TextMessageGenerator.new( new_channel.channel_people[0], general_messages[0] )

        assert_match I18n.t('channel_topics.channel.start.success.included_header_addendum'), generator.to_s
      end
    end
  end
end
