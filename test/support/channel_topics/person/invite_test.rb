require 'test_helper'

module ChannelTopics
  module Person
    class InviteTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def root_channel
        super.tap{|c| c.business.facebook_place.update_attributes(name: 'My Business Name')}
      end

      def inviter_phone_number
        inviter.channel_people.find{|cp| cp.channel_id == root_channel.id }.channel_phone_number
      end

      def basic_invite_message
        @basic_invite_message ||= TextMessage.new(
          to: inviter_phone_number,
          message_from: inviter.mobile, sender: inviter, message_text: '#invite'
        )
      end

      def invite_groups
        @invite_groups ||= [
          TextGroup.create!( business: root_channel.business, name: 'managers'),
          TextGroup.create!( business: root_channel.business, name: 'grupo súper secreto')
        ]
      end

      def invite_message_with_groups
        @invite_message_with_groups ||= TextMessage.new(
          to: inviter_phone_number,
          message_from: inviter.mobile, sender: inviter, message_text: "#invite to #{invite_groups.map(&:name).join(', ')}"
        )
      end

      def inviter
        @inviter ||= ::Person.create!(
          name: 'Shirley Eastman', mobile: '+2482886001'
        ).tap{|person| root_channel.people << person }
      end

      def assert_instructions_text( instructions )
        text = generate_text(instructions)
        encoded_root_number = UnicodeFormatting.url_escape( inviter.channel_people.first.channel_phone_number.to_s(:url) )
        puts text
        assert_equal [inviter.mobile], instructions.to
        assert_match encoded_root_number, text
        # assert_match 'GIVE THEM A CODE', text
        # There should be a double encoded invite link
        assert_match /#{UnicodeFormatting.url_escape('!inv-mybusi-')}[a-z]{6}/, text
        assert_match /\!inv-mybusi-[a-z]{6}/, text
        # assert_match inviter_phone_number.formatted, text
        encoded_url = text.match(/#{Rails.application.config.x.host}[^\n]+/).to_s
        assert_match /\/s\/a\/!inv-mybusi-[a-z]{6}/, Addressable::URI.unencode(encoded_url)
      end

      def assert_instructions_job(instructions_job)
        assert instructions_job
      end

      test 'a user gets instructions for sending a message to people they want to join' do
        topic = ChannelTopics::Person::Invite.new( basic_invite_message, root_channel )
        topic_called_at = Time.now
        topic.call

        channel_messages = TextMessage.where( channel: root_channel )
        assert_equal 1, channel_messages.size

        instructions = channel_messages.first
        forwardable_msg = channel_messages.last

        assert_instructions_text(instructions)

        assert_match '#invite group1', generate_text(instructions)

        instructions_job = TextMessageWorker::Send.jobs.find{|j| j['args'][0] == instructions.id }
        forwardable_msg_job = TextMessageWorker::Send.jobs.find{|j| j['args'][0] == forwardable_msg.id }

        assert_instructions_job(instructions_job)
      end

      test 'a user gets instructions for adding people to groups' do
        topic = ChannelTopics::Person::Invite.new( invite_message_with_groups, root_channel )
        topic_called_at = Time.now
        topic.call

        channel_messages = TextMessage.where( channel: root_channel )
        assert_equal 1, channel_messages.size

        instructions = channel_messages.first
        forwardable_msg = channel_messages.last

        assert_instructions_text(instructions)

        invite_groups.each do |group|
          assert_match group.name, generate_text(instructions)
        end
      end
    end
  end
end
