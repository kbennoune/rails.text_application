require 'test_helper'

module ChannelTopics
  module Person
    class AddTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def business
        Business.new name: "Wine & Cheese Unlimited"
      end

      def root_channel
        @root_channel ||= ::Channel.create! topic: ::Channel::ROOT_TOPIC, business: business
      end

      def inviter
        ::Person.create! name: 'Inviter', mobile: '2122223333', channels: [ root_channel ]
      end

      test 'creates people in specified groups' do
        message_text = "#invite to everyone, kitchen staff : (91912345678 John Smith) (Joan Smith 91912345679)"

        message = TextMessage.new message_from: inviter.mobile, sender: inviter, message_text: message_text, channel: root_channel
        topic = ChannelTopics::Person::Add.new( message, message.channel )

        topic.call
        invite_channel = topic.invite_channel
        assert invite_channel.persisted?

        topic.contacts_from_definitions.each do |contact|
          assert contact.persisted?
          assert_equal contact.service_invitations[0].try(:service_location), invite_channel
          assert_equal ["everyone", "kitchen staff"].to_set, contact.service_invitations[0].service_groups_to_add.map(&:name).to_set
        end
      end

      test 'creates people in existing groups' do
        existing_group = TextGroup.create! name: 'kitchen staff', business: root_channel.business
        message_text = "#invite to everyone, kitchen staff : (9191234567 John Smith) (Joan Smith 9191234568)"

        message = TextMessage.new message_from: inviter.mobile, sender: inviter, message_text: message_text, channel: root_channel
        topic = ChannelTopics::Person::Add.new( message, message.channel )

        topic.call
        invite_channel = topic.invite_channel
        assert invite_channel.persisted?

        topic.contacts_from_definitions.each do |contact|
          assert contact.persisted?
          assert_equal contact.service_invitations[0].try(:service_location), invite_channel
          assert_equal ["everyone", "kitchen staff"].to_set, contact.service_invitations[0].service_groups_to_add.map(&:name).to_set
          assert_includes contact.service_invitations[0].service_groups_to_add, existing_group
          assert_match /\d{10}/, contact.mobile.digits
        end
      end

      test "updates existing people's names and groups" do
        existing_person = ::Person.create!( mobile: '9191234567', name: 'JSmith', channels: [ root_channel ] )
        message_text = "#invite to everyone, kitchen staff : (9191234567 John Smith) (Joan Smith 9191234568)"

        message = TextMessage.new message_from: inviter.mobile, sender: inviter, message_text: message_text, channel: root_channel
        topic = ChannelTopics::Person::Add.new( message, message.channel )

        topic.call
        invite_channel = topic.invite_channel
        assert invite_channel.persisted?

        topic.contacts_from_definitions.each do |contact|
          assert contact.persisted?
        end

        updated_person = topic.contacts_from_definitions.find{|contact| contact.mobile == existing_person.mobile }
        assert_equal existing_person.id, updated_person.id
        assert_equal 'John Smith', updated_person.name
        assert_equal ["everyone", "kitchen staff"].to_set, updated_person.text_groups.map(&:name).to_set
      end
    end
  end
end
