require 'test_helper'

module ChannelTopics
  module Group
    class ListTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def group_names
        [
          'simple',
          'compound words',
          "some-complex-thing with \ttabs"
        ]
      end

      def business_name
        "This is a business!"
      end

      def help_requester
        @help_requester ||= ::Person.create!( name: 'Shirley Eastman', mobile: '+2482886001' ).tap do |person|
          group_names.each do |name|
            TextGroup.create!( name: name, business: root_channel.business )
          end
          root_channel.business.facebook_place.update_attributes( name: business_name )
          person.channels << root_channel
        end
      end

      def incoming_message
        ::TextMessage.new message_text: '#list all groups', message_from: help_requester.mobile, sender: help_requester
      end

      test 'a participant can receive a text with all the availabe groups' do
        topic = ChannelTopics::Group::List.new(incoming_message, root_channel)
        topic.call

        channel_messages = TextMessage.where( channel: root_channel )
        assert_equal 1, channel_messages.size

        assert_match business_name, generate_text(channel_messages.first)

        group_names.each do |name|
          assert_match name.titleize, generate_text(channel_messages.first)
        end
      end
    end
  end
end
