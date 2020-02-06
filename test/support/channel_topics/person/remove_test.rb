require 'test_helper'

module ChannelTopics
  module Person
    class RemoveTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def around(&test)
        UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
          test.call
        end
      end

      def remove_message(*people)
        "#erase #{people.map(&:name).join(', ')}"
      end

      def people
        @people ||= restaurant_people.each do |_,p|
          p.channels << root_channel
          p.channels << chat_channel
          p.save!
        end
      end

      def assert_business_channels_removed( person, channel=root_channel )
        channel_empty = person.channels.where( business_id: channel.business_id ).empty?
        assert channel_empty
      end

      def assert_business_channel_size( num, person, channel=root_channel )
        num_channels = person.channels.where(
          business_id: channel.business_id
        ).size
        assert_equal(num, num_channels)
      end

      test 'removes a person from root channel' do
        assert_business_channel_size( 2, people['Taylor Server'])
        processor = ::ChannelTopics::Person::Remove.new(
          new_text_message( message_text: remove_message(
            people['Taylor Server']),
            message_from: people['Jaime Manager'].mobile, sender: people['Jaime Manager']
          ),
          chat_channel
        )

        processor.call
        assert_business_channels_removed people['Taylor Server']
      end

      test 'removes people from the root channel' do
        people_to_remove = people.values_at('Taylor Server', 'Francis Dishwasher', 'Terry Chef')

        people_to_remove.each do |person|
          assert_business_channel_size 2, person
        end
        processor = ::ChannelTopics::Person::Remove.new(
          new_text_message(
            message_text: remove_message( *people_to_remove ),
            message_from: people['Jaime Manager'].mobile, sender: people['Jaime Manager']
          ),
          chat_channel
        )
        processor.call

        people_to_remove.each do |person|
          assert_business_channels_removed person
        end

        remaining_people = people.values - people_to_remove
        assert_equal 2, remaining_people.size
        remaining_people.each do |person|
          assert_business_channel_size 2, person
        end
      end

      test 'removes people from all groups that they belong to' do
        people_to_remove = people.values_at('Taylor Server', 'Francis Dishwasher', 'Terry Chef')

        groups = [
          TextGroup.create!( business: root_channel.business, name: 'group one'),
          TextGroup.create!( business: root_channel.business, name: 'group two')
        ]

        groups.each do |group|
          group.people << people_to_remove
          group.people << people['Jaime Manager']
        end

        people_to_remove.each do |person|
          assert_business_channel_size 2, person
        end

        processor = ::ChannelTopics::Person::Remove.new(
          new_text_message(
            message_text: remove_message( *people_to_remove ),
            message_from: people['Jaime Manager'].mobile, sender: people['Jaime Manager']
          ),
          root_channel
        )
        processor.call

        groups.each do |group|
          group.reload
          people_to_remove.each do |removed|
            assert !group.people.include?(removed)
          end

          assert group.people.include?( people['Jaime Manager'] )
        end
      end

    end
  end
end
