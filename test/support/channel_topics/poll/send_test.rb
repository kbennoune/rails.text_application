require 'test_helper'

module ChannelTopics
  module Poll
    class SendTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def people
        @people ||= [
          ::Person.new( name: 'Jaime Manager', mobile: '5555551000'),
          ::Person.new( name: 'Terry Chef', mobile: '5555551001'),
          ::Person.new( name: 'Jesse Server', mobile: '5555551002'),
          ::Person.new( name: 'Taylor Server', mobile: '5555551003')
        ].inject({}){|acc, p| acc[p.name] = p; acc}
      end

      def incoming_response
        @incoming_message ||= new_text_message(
          message_text: "Here's my answer",
          channel: channel,
          message_from:  people['Jesse Server'].mobile, sender:  people['Jesse Server']
        )
      end

      def additional_text
        @incoming_message ||= new_text_message(
          channel: channel,
          message_text: "And another thing!",
          message_from:  people['Jaime Manager'].mobile, sender:  people['Jaime Manager']
        )
      end

      def channel
        @channel ||= ::Channel.create! people: people.values, business: business, topic: ::Channel::POLL_TOPIC, started_by_person:  people['Jaime Manager']
      end

      test 'queues a message to the original poll creator' do
        processor = ChannelTopics::Poll::Send.new(incoming_response, channel)
        processor.call

        assert_equal 1, TextMessageWorker::Send.jobs.size
        TextMessageWorker::Send.jobs.each do |j|
          tm = TextMessage.find j['args'][0]
          assert tm

          assert_equal channel.id, tm.channel_id
          assert_equal [ people['Jaime Manager'].mobile ], tm.to
          assert_match generate_text(incoming_response), normalized(generate_text(tm))
        end
      end


      test 'queues an additional message from the poll creator to the entire channel' do
        processor = ChannelTopics::Poll::Send.new(additional_text, channel)
        processor.call

        assert_equal 1, TextMessageWorker::Send.jobs.size
        TextMessageWorker::Send.jobs.each do |j|
          tm = TextMessage.find j['args'][0]
          assert tm

          assert_equal channel.id, tm.channel_id
          assert tm.to.blank?

          assert_match generate_text(incoming_response), normalized(generate_text(tm))
        end
      end

    end
  end
end
