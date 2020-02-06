require 'test_helper'

module ChannelTopics
  module Channel
    class HelpTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def incoming_message( attrs )
        ::TextMessage.new attrs
      end

      def people
        @people ||= begin
          [
            ::Person.create!( name: 'Shirley Eastman', mobile: '+2482886001' ),
            ::Person.create!( name: 'Amal King', mobile: '+2482886002' ),
            ::Person.create!( name: 'Mervin Nesbit', mobile: '+2482886003' ),
            ::Person.create!( name: 'Karen Strong-Smith', mobile: '+2482886004' )
          ].each{|person|
            root_channel.channel_people << ChannelPerson.new( person_id: person.id )
            chat_channel.channel_people << ChannelPerson.new( person_id: person.id )
          }
        end
      end

      test 'sends a chat specific help text to the sender' do
        topic = ChannelTopics::Channel::Help.new(incoming_message( message_from: people[0].mobile, sender: people[0], message_text: '#help' ), chat_channel)
        topic.call

        channel_messages = TextMessage.where( channel_id: chat_channel )
        assert_equal 1, channel_messages.size
        assert_match /#add ([^\n]+,)+/, normalized(generate_text(channel_messages.first))
        assert_match /#remove ([^\n]+,)+/, normalized(generate_text(channel_messages.first))
        assert_match /#stop/, normalized(generate_text(channel_messages.first))
        assert_match /#list/, normalized(generate_text(channel_messages.first))

        assert_equal [people[0].mobile], channel_messages.first.to
      end

      test 'sends a root specific help text to the sender' do
        topic = ChannelTopics::Channel::Help.new(incoming_message( message_from: people[0].mobile, sender: people[0], message_text: '#help' ), root_channel)
        topic.call

        channel_messages = TextMessage.where( channel_id: root_channel )
        assert_equal 1, channel_messages.size
        assert_match /body=@/, normalized(generate_text(channel_messages.first))
        assert_match /#remove ([^\n]+)+/, normalized(generate_text(channel_messages.first))
        assert_match /INVITES/, normalized(generate_text(channel_messages.first))
        assert_match /#list/, normalized(generate_text(channel_messages.first))

        assert_equal [people[0].mobile], channel_messages.first.to
      end

      test 'includes numbers for permanent groups' do
        text_group = TextGroup.create! business: business, people: people.values_at(0), name: "Some group name"
        ::Channel.create_group_channel(business, text_group)

        Sidekiq::Worker.drain_all

        topic = ChannelTopics::Channel::Help.new(incoming_message( message_from: people[0].mobile, sender: people[0], message_text: '#help' ), root_channel)
        topic.call

        help_message = TextMessage.where( channel_id: root_channel ).first
        help_text = generate_text( help_message )

        assert_match "Some Group Name", help_text
        assert_match "sms:#{people[0].channel_people.last.channel_phone_number.to_s(:url)}", help_text

      end

    end
  end
end
