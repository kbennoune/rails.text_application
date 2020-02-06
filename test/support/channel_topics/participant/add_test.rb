require 'test_helper'

module ChannelTopics
  module Participant
    class AddTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def around(&test)
        UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
          test.call
        end
      end

      def add_message(*people)
        "#add #{people.map(&:name).join(', ')}"
      end

      def people
        @people ||= restaurant_people.each do |_,p|
          p.channels << root_channel
          p.save!
        end
      end

      test 'add another user to an existing channel' do
        people.values_at('Jaime Manager', 'Francis Dishwasher').each do |person|
          person.channels << chat_channel
        end

        processor = ::ChannelTopics::Participant::Add.new(
          new_text_message(
            message_text: add_message( people['Taylor Server']),
            message_from: people['Jaime Manager'].mobile, sender: people['Jaime Manager']
          ),
          chat_channel
        )

        processor.call
        assert people['Taylor Server'].reload.channels.include?(chat_channel)
      end

      test 'add multiple users to an existing channel' do
        people.values_at('Jaime Manager', 'Francis Dishwasher').each do |person|
          person.channels << chat_channel
        end

        processor = ::ChannelTopics::Participant::Add.new(
          new_text_message(
            message_text: add_message( *people.values_at('Taylor Server','Terry Chef')),
            message_from: people['Jaime Manager'].mobile, sender: people['Jaime Manager']
          ),
          chat_channel
        )

        processor.call
        assert people['Taylor Server'].reload.channels.include?(chat_channel)
        assert people['Terry Chef'].reload.channels.include?(chat_channel)
        # assert chat_channel.reload.text_messages.find_all{|tm|}
        # assert processor.introductory_text_message.persisted?
      end

    end
  end
end
