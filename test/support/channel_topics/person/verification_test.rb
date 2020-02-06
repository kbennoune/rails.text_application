require 'test_helper'

module ChannelTopics
  module Person
    class VerificationTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def business
        @business ||= Business.new name: "Wine & Cheese Unlimited"
      end

      def inviter
        @inviter ||= ::Person.new( name: 'Some other person', mobile: '2121112222' )
      end

      def invite_channel
        @invite_channel ||= ::Channel.create! topic: ::Channel::INVITE_TOPIC, business: business
      end

      test 'a yes message will add the user to the root channel' do
        assert root_channel.persisted?
        invited = ::Person.create( name: 'James Rodriguez', channels: [ invite_channel ], mobile: '9193221111' )
        message = TextMessage.new message_from: invited.mobile, sender: invited, message_text: 'Yes', channel: invite_channel
        topic = ChannelTopics::Person::Verification.new( message, message.channel )
        topic.call

        assert_includes invited.channels.reload, root_channel
        assert_not_includes invited.channels, invite_channel
        assert topic.welcome_message.persisted?
      end

      test 'a no message will add the user to the root channel' do
        assert root_channel.persisted?
        invited = ::Person.create( name: 'James Rodriguez', channels: [ invite_channel ], mobile: '9193221111' )
        message = TextMessage.new message_from: invited.mobile, sender: invited, message_text: 'no', channel: invite_channel
        topic = ChannelTopics::Person::Verification.new( message, message.channel )
        topic.call

        assert_not_includes invited.channels.reload, root_channel
        assert_includes invited.channels, invite_channel
        assert !topic.welcome_message.persisted?
      end

      test 'a yes message will add the user to text groups they are invited to' do
        assert root_channel.persisted?
        invited = ::Person.create( name: 'James Rodriguez', channels: [ invite_channel ], mobile: '9193221111' )
        text_groups = [ TextGroup.create!(business: business, name: 'everyone'), TextGroup.create!(business: business, name: 'other text group') ]
        invited.service_invitations.create!( inviting_person: inviter, service_location: invite_channel, service_groups_to_add: text_groups )
        message = TextMessage.new message_from: invited.mobile, sender: invited, message_text: 'Yes', channel: invite_channel
        topic = ChannelTopics::Person::Verification.new( message, message.channel )
        topic.call

        text_groups.each do |group|
          assert_includes invited.text_groups, group
        end
      end

      test 'a yes message sends a response to the person signing up with a contact file' do
        assert root_channel.persisted?
        invited = ::Person.create( name: 'James Rodriguez', channels: [ invite_channel ], mobile: '9193221111' )
        text_groups = [ TextGroup.create!(business: business, name: 'everyone'), TextGroup.create!(business: business, name: 'other text group') ]

        text_groups.each{|group| ::Channel.create!(business: business, topic: ::Channel::ROOM_TOPIC, channel_groups: [ChannelGroup.new( text_group: group )]) }

        invited.service_invitations.create!( inviting_person: inviter, service_location: invite_channel, service_groups_to_add: text_groups )

        message = TextMessage.new message_from: invited.mobile, sender: invited, message_text: 'Yes', channel: invite_channel
        topic = ChannelTopics::Person::Verification.new( message, message.channel )
        topic.call

        assert topic.welcome_message.persisted?
        text = generate_text(topic.welcome_message)

        assert_match inviter.mention_code(within: root_channel), normalized(text)
        text_groups.each do |group|
          assert_match group.name.titleize, text
        end
      end

      test 'a yes message without an inviter sends a response to the person signing up with a contact file' do
        assert root_channel.persisted?
        invited = ::Person.create( name: 'James Rodriguez', channels: [ invite_channel ], mobile: '9193221111' )

        message = TextMessage.new message_from: invited.mobile, sender: invited, message_text: 'Yes', channel: invite_channel
        topic = ChannelTopics::Person::Verification.new( message, message.channel )
        topic.call

        assert topic.welcome_message.persisted?
        text = generate_text(topic.welcome_message)

        assert_match '@artie', normalized(text)
      end

      test 'a yes message will send a notification to the inviter' do
        assert root_channel.persisted?
        invited = ::Person.create( name: 'James Rodriguez', channels: [ invite_channel ], mobile: '9193221111' )
        text_groups = [ TextGroup.create!(business: business, name: 'everyone'), TextGroup.create!(business: business, name: 'other text group') ]
        invited.service_invitations.create!( inviting_person: inviter, service_location: invite_channel, service_groups_to_add: text_groups )
        message = TextMessage.new message_from: invited.mobile, sender: invited, message_text: 'Yes', channel: invite_channel
        topic = ChannelTopics::Person::Verification.new( message, message.channel )
        topic.call

        assert topic.accept_notification_message.persisted?
        text = generate_text(topic.accept_notification_message)

        assert_match invited.display_name, text
        assert_match 'joined', text
      end

      test 'a no message will send a notification to the inviter' do
        assert root_channel.persisted?
        invited = ::Person.create( name: 'James Rodriguez', channels: [ invite_channel ], mobile: '9193221111' )
        text_groups = [ TextGroup.create!(business: business, name: 'everyone'), TextGroup.create!(business: business, name: 'other text group') ]
        invited.service_invitations.create!( inviting_person: inviter, service_location: invite_channel, service_groups_to_add: text_groups )
        message = TextMessage.new message_from: invited.mobile, sender: invited, message_text: 'no', channel: invite_channel
        topic = ChannelTopics::Person::Verification.new( message, message.channel )
        topic.call

        assert topic.reject_notification_message.persisted?
        text = generate_text(topic.reject_notification_message)

        assert_match invited.display_name, text
        assert_match 'rejected', text
      end
    end
  end
end
