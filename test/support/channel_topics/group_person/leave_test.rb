require 'test_helper'

module ChannelTopics
  module GroupPerson
    class LeaveTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def around(&test)
        UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
          test.call
        end
      end

      def people
        @people ||= restaurant_people.each{|_,person| root_channel.people << person }
      end

      def rem_from_group_command(*groups)
        "#leave from #{groups.join(', ')}"
      end

      test 'remove yourself from a room channel' do
        removing_person = people.values[0]
        existing_group = TextGroup.create!( business: business, name: 'managers' )
        existing_group.people << removing_person

        room_channel = ::Channel.create_group_channel(business, existing_group )

        Sidekiq::Worker.drain_all

        text_message = TextMessage.create! message_text: '#leave', channel: room_channel, message_from: removing_person.mobile, sender: removing_person
        topic = ChannelTopics::GroupPerson::Leave.new text_message, room_channel
        topic.call

        assert !existing_group.people.reload.include?(removing_person)
        success_message = TextMessage.where( channel: room_channel ).where(TextMessage.arel_table[:message_generator_keys].matches( Arel::Nodes::Casted.new('%channel_topics.group_person.leave.success%',nil) )).last
        message_text = generate_text(success_message)
        assert_match /[Rr]emoved/, message_text
        assert_match existing_group.name, message_text
      end

      test 'remove yourself from another group' do
        removing_person = people.values[0]
        existing_group = TextGroup.create!( business: business, name: 'some other group' )
        existing_group.people << removing_person

        text_message = TextMessage.create! message_text: rem_from_group_command(existing_group.name), channel: root_channel, message_from: removing_person.mobile, sender: removing_person
        topic = ChannelTopics::GroupPerson::Leave.new text_message, root_channel
        topic.call

        assert !existing_group.people.reload.include?(removing_person)
        success_message = TextMessage.where( channel: root_channel ).where(TextMessage.arel_table[:message_generator_keys].matches( Arel::Nodes::Casted.new('%channel_topics.group_person.leave.success%',nil) )).last

        message_text = generate_text(success_message)
        assert_match /[Rr]emoved/, message_text
        assert_match existing_group.name, message_text
      end

    end
  end
end
