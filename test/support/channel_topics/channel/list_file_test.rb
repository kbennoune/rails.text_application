require 'test_helper'

module ChannelTopics
  module Channel
    class ListFileTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def business
        @business ||= Business.new name: 'TextAware Dry Cleaning'
      end

      def root_channel
        super.tap{|channel| channel.business = business }
      end

      def chat_channel
        super.tap{|channel| channel.business = business }
      end

      def person
        @person ||= ::Person.create!( name: 'Shirley Eastman', mobile: '+2482886001' ).tap do |person|
          root_channel.people << person
          chat_channel.people << person
        end
      end

      test 'it sends an up to date contact file to the requester from a root channel' do
        request_message = TextMessage.new message_text: '#contact', message_from: person.mobile, sender: person

        topic = ChannelTopics::Channel::ListFile.new( request_message, root_channel )
        topic.call

        assert topic.list_message.persisted?
        assert_equal business.name, topic.list_message.message_generator_keys.dig(0, 'values', 'business_name')
        assert_match 'skip=ssl', topic.list_message.message_media[0]
        assert_match 'skip=ssl', topic.list_message.message_media[0]
        assert_match "contacts/#{business.id}/#{person.id}/app", topic.list_message.message_media[0]
      end

      test 'it sends an up to date contact file to the requester from a chat channel' do
        request_message = TextMessage.new message_text: '#contact', message_from: person.mobile, sender: person

        topic = ChannelTopics::Channel::ListFile.new( request_message, chat_channel )
        topic.call

        assert topic.list_message.persisted?
        assert_equal business.name, topic.list_message.message_generator_keys.dig(0, 'values', 'business_name')
        assert_match 'skip=ssl', topic.list_message.message_media[0]
        assert_match 'skip=ssl', topic.list_message.message_media[0]
        assert_match "contacts/#{business.id}/#{person.id}/app", topic.list_message.message_media[0]
      end
    end
  end
end
