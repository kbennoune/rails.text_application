require 'test_helper'

module ChannelTopics
  class MatcherTest < ActiveSupport::TestCase
    include ChannelTopics::TestHelpers

    def manager_phone_number
      '5555550000'
    end

    def app_phone_number
      '5551234567'
    end

    def add_person_text
      'add to managers'
    end

    def remove_person_text
      'remove John'
    end

    def start_channel_text
      "#chat managers, RJ, someone else: \n This is a chat!!!"
    end

    def remove_participant_text
      "#remove john"
    end

    def add_participant_text
      "#add johnton"
    end

    def send_message_text
      "Is this thing on???"
    end

    def manager_message(additional_attrs={})
      msg_attrs = {
        message_from: manager_phone_number,
        to: app_phone_number, message_to:  app_phone_number,
        message_media: ['https://something/else.crp']
      }

      msg_attrs = msg_attrs.merge(additional_attrs){|k,oldval,newval|
        oldval.kind_of?(Array) && newval.kind_of?(Array) ? newval + oldval : newval
      }

      TextMessage.new(msg_attrs)
    end

    class NoTopicTest < ChannelTopics::MatcherTest

      def channel
        nil
      end

      test 'handles accept messages' do
        message_text = <<~EOS
        Some kind of randomstrking
          !inv-bül123-rdmpss
        @ Eliot Gould
        EOS
        message = TextMessage.new message_text: message_text, to: '+1213334444'
        channel_topic_obj = ChannelTopics::Matcher.new( message, channel ).topic
        assert_kind_of ChannelTopics::Person::Accept, channel_topic_obj
      end
    end

    class RootTopicTest < ChannelTopics::MatcherTest

      def channel
        root_channel
      end

      test 'add a person if there is a vcard' do
        message = manager_message( message_text: add_person_text, message_media: ['https://some/info/for/contact.vcard'] )
        channel_topic_obj = ChannelTopics::Matcher.new( message, channel ).topic
        assert_kind_of( ChannelTopics::Person::Create, channel_topic_obj )
      end

      test 'remove a person if there is a vcard and a removal request' do
        message = manager_message( message_text: remove_person_text, message_media: ['https://some/info/for/contact.vcard'] )

        channel_topic_obj = ChannelTopics::Matcher.new( message, channel ).topic
        assert_kind_of( ChannelTopics::Person::Remove, channel_topic_obj )
      end

      test 'start chatting with a group if there is chat request' do
        message = manager_message( message_text: start_channel_text )

        channel_topic_obj = ChannelTopics::Matcher.new( message, channel ).topic
        assert_kind_of( ChannelTopics::Channel::Start, channel_topic_obj )
      end

      test 'adds a person to a group' do
        message = manager_message( message_text: "#add john and joan to group one, group 2")
        channel_topic_obj = ChannelTopics::Matcher.new( message, channel ).topic

        assert_kind_of( ChannelTopics::GroupPerson::Add, channel_topic_obj )
      end

      test 'sends invite information to the manager' do
        message = manager_message( message_text: "#invite")
        channel_topic_obj = ChannelTopics::Matcher.new( message, channel ).topic

        assert_kind_of( ChannelTopics::Person::Invite, channel_topic_obj )
      end

      test 'handles simple new chat requests' do
        message = manager_message(message_text: "@person1 @person2 group \nLet's get chatting")

        channel_topic_obj = ChannelTopics::Matcher.new( message, channel ).topic
        assert_kind_of( ChannelTopics::Channel::Start, channel_topic_obj )

        message = manager_message(message_text: "@person1 @person2 group \nLet's get chatting about #somthing")
        channel_topic_obj = ChannelTopics::Matcher.new( message, channel ).topic
        assert_kind_of( ChannelTopics::Channel::Start, channel_topic_obj )

        message = manager_message(message_text: "@person1 Let's get chatting about #somthing")
        channel_topic_obj = ChannelTopics::Matcher.new( message, channel ).topic
        assert_kind_of( ChannelTopics::Channel::Start, channel_topic_obj )
      end


      test "won't start a chat if the user was trying to do something else" do
        message = manager_message(message_text: "#somthing I'm trying @person1 @person2 group \nLet's get chatting")

        channel_topic_obj = ChannelTopics::Matcher.new( message, channel ).topic
        assert_kind_of( ChannelTopics::Unknown::Handle, channel_topic_obj )
      end
    end

    class ChatTopicTest < ChannelTopics::MatcherTest
      def channel
        chat_channel
      end

      test 'starts a new message in a new channel' do
        message = manager_message( message_text: start_channel_text )
        channel_topic_obj = ChannelTopics::Matcher.topic( message, channel )
        assert_kind_of( ChannelTopics::Channel::Start, channel_topic_obj )
      end

      test 'remove a user from a conversation' do
        message = manager_message( message_text: remove_participant_text )
        channel_topic_obj = ChannelTopics::Matcher.new( message, channel ).topic
        assert_kind_of( ChannelTopics::Participant::Remove , channel_topic_obj )
      end

      test 'add a user to a conversation' do
        message = manager_message( message_text: add_participant_text )
        channel_topic_obj = ChannelTopics::Matcher.new( message, channel ).topic
        assert_kind_of( ChannelTopics::Participant::Add , channel_topic_obj )
      end

      test 'send a message to all the recipinets' do
        message = manager_message( message_text: send_message_text )
        channel_topic_obj = ChannelTopics::Matcher.new( message, channel ).topic
        assert_kind_of( ChannelTopics::Message::Send, channel_topic_obj )
      end
    end
  end
end
