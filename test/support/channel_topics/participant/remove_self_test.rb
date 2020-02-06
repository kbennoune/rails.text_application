require 'test_helper'

module ChannelTopics
  module Participant
    class RemoveSelfTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def people
        @people ||= restaurant_people.each do |_,p|
          p.channels << root_channel
          p.channels << chat_channel
          p.save!
        end
      end

      test 'removes a user from the chat channel' do
        person_stopping = people.values.last
        person_stopping_root_number = person_stopping.channel_people.find{|cp| cp.channel.topic == ::Channel::ROOT_TOPIC }.channel_phone_number
        text_message = ::TextMessage.new( message_from: person_stopping.mobile, sender: person_stopping, message_text: '#stop', to: person_stopping_root_number )

        topic = ChannelTopics::Participant::RemoveSelf.new( text_message, chat_channel )
        topic.call

        assert !person_stopping.reload.channels.include?( chat_channel )
        people.values.reject{|p| p == person_stopping }.each do |other_people|
          assert other_people.reload.channels.include?( chat_channel )
        end

        assert topic.successful_remove_message.persisted?
        assert_equal  person_stopping_root_number, topic.successful_remove_message.message_from
      end

    end
  end
end
