require 'test_helper'

module ChannelTopics
  module GroupPerson
    class ListTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def around(&test)
        UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
          test.call
        end
      end

      def setup
        root_channel
        restaurant_groups
        super
      end

      test 'lists users in a group from the chat channel' do
        list_front_of_the_house_text = '#list @fronthouse'
        list_managers_text = '#list managers'

        list_foh_msg = ::TextMessage.new message_from: restaurant_people['Jaime Manager'], message_text: list_front_of_the_house_text

        foh_topic = ChannelTopics::GroupPerson::List.new(list_foh_msg, chat_channel)
        foh_topic.call

        assert foh_topic.list_message.persisted?
        message_keys = foh_topic.list_message.message_generator_keys.dig(0,'values')

        assert_equal restaurant_groups['front of the house'].people.map(&:display_name).to_set, message_keys['people'].to_set

        list_managers_msg = ::TextMessage.new message_from: restaurant_people['Jaime Manager'], message_text: list_managers_text

        managers_topic = ChannelTopics::GroupPerson::List.new(list_managers_msg, chat_channel)
        managers_topic.call

        assert managers_topic.list_message.persisted?
        message_keys = managers_topic.list_message.message_generator_keys.dig(0,'values')

        assert_equal restaurant_groups['managers'].people.map(&:display_name).to_set, message_keys['people'].to_set

      end

      test 'it sends a failure message if the group cannot be found' do
        failing_msg = ::TextMessage.new message_text: '#list ERROR', message_from: restaurant_people['Jaime Manager']

        topic = ChannelTopics::GroupPerson::List.new(failing_msg, chat_channel)
        topic.call

        assert topic.failed_missing_group_message.persisted?
        text = TextMessageGenerator.new( restaurant_people['Jaime Manager'], topic.failed_missing_group_message, cache: {}, values: { channel_phone_number: ApplicationPhoneNumber.last.number } ).to_s
        assert_match 'list of groups', text
      end
    end
  end
end
