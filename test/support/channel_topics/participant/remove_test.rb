require 'test_helper'

module ChannelTopics
  module Participant
    class RemoveTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def around(&test)
        UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
          test.call
        end
      end

      def remove_message(*people)
        "#remove #{people.map(&:name).join(', ')}"
      end

      def people
        @people ||= restaurant_people.each do |_,p|
          p.channels << root_channel
          p.save!
        end
      end

      test 'remove a user from an existing channel' do
        people.values_at('Jaime Manager', 'Francis Dishwasher', 'Taylor Server').each do |person|
          person.channels << chat_channel
        end

        processor = ::ChannelTopics::Participant::Remove.new(
          new_text_message(
            message_text: remove_message( people['Taylor Server']),
            message_from: people['Jaime Manager'].mobile, sender: people['Jaime Manager']
           ),
          chat_channel
        )

        processor.call
        assert !people['Taylor Server'].reload.channels.include?(chat_channel)
      end

      test 'remove a user from an existing channel using a mention' do
        people.values_at('Jaime Manager', 'Francis Dishwasher', 'Taylor Server').each do |person|
          person.channels << chat_channel
        end

        ::Person.bulk_update_fuzzy_name

        processor = ::ChannelTopics::Participant::Remove.new(
          new_text_message(
            message_text: remove_message( OpenStruct.new(name: '@taylor') ),
            message_from: people['Jaime Manager'].mobile, sender: people['Jaime Manager']
           ),
          chat_channel
        )

        processor.call
        assert !people['Taylor Server'].reload.channels.include?(chat_channel)
      end

      test 'remove multiple users from an existing channel' do
        people.values_at('Jaime Manager', 'Francis Dishwasher', 'Taylor Server').each do |person|
          person.channels << chat_channel
        end

        processor = ::ChannelTopics::Participant::Remove.new(
          new_text_message(
            message_text: remove_message( *people.values_at('Taylor Server', 'Francis Dishwasher')),
            message_from: people['Jaime Manager'].mobile, sender: people['Jaime Manager']
          ),
          chat_channel
        )

        processor.call
        assert !people['Taylor Server'].reload.channels.include?(chat_channel)
        assert !people['Francis Dishwasher'].reload.channels.include?(chat_channel)
      end

      test 'skips misspelled when removing from an existing channel' do
        people.values_at('Jaime Manager', 'Francis Dishwasher', 'Taylor Server').each do |person|
          person.channels << chat_channel
        end

        processor = ::ChannelTopics::Participant::Remove.new(
          new_text_message(
            message_text: remove_message( people['Taylor Server'], ::Person.new( name: 'Frni Sishwsr')),
            message_from: people['Jaime Manager'].mobile, sender: people['Jaime Manager']
          ),
          chat_channel
        )

        processor.call
        assert !people['Taylor Server'].reload.channels.include?(chat_channel)
        assert people['Francis Dishwasher'].reload.channels.include?(chat_channel)
      end

    end
  end
end
