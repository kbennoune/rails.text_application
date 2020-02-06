require 'test_helper'

module ApiActions
  module AuthenticationMessage
    class SendTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def requester
        @requester ||= ::Person.create! name: Faker::Name.name, mobile: Faker::PhoneNumber.cell_phone
      end

      def channel
        @channel ||= ::Channel.create! topic: ::Channel::ROOT_TOPIC, business: business
      end

      def business
        @business ||= Business.create!
      end

      test 'it saves an authentication code' do
        authentication_code = ::AuthenticationCode.new( person: requester )
        action  = ApiActions::AuthenticationMessage::Send.new( requester, authentication_code, channel )
        action.call
        assert authentication_code.persisted?
      end

      test 'is sends a message with the authentication code' do
        authentication_code = ::AuthenticationCode.new( person: requester )
        action  = ApiActions::AuthenticationMessage::Send.new( requester, authentication_code, channel )
        action.call

        TextMessageWorker::Send.jobs.each do |job|
          text_message = TextMessage.find job['args'][0]
          assert text_message

          assert_equal channel.id, text_message.channel_id
          assert_match authentication_code.code, generate_text(text_message)
          assert_equal requester.mobile, text_message.to[0]

        end
      end
    end
  end
end
