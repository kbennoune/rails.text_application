require 'test_helper'

module ChannelTopics
  module Message
    class SendTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def people
        [
          ::Person.new( name: 'Jaime Manager', mobile: '5555551000'),
          ::Person.new( name: 'Terry Chef', mobile: '5555551001'),
          ::Person.new( name: 'Jesse Server', mobile: '5555551002'),
          ::Person.new( name: 'Taylor Server', mobile: '5555551003')
        ].inject({}){|acc, p| acc[p.name] = p; acc}
      end

      def incoming_message
        @incoming_message ||= new_text_message(
          message_text: 'Hey is this thing on?',
          message_from:  people['Jaime Manager'].mobile, sender:  people['Jaime Manager']
        )
      end

      test 'queues a message on to all the recipients' do
        channel = new_chat_channel( people: people.values ).tap(&:save!)

        processor = ChannelTopics::Message::Send.new(incoming_message, channel)
        processor.call

        assert_equal 1, TextMessageWorker::Send.jobs.size

        TextMessageWorker::Send.jobs.each do |j|
          tm = TextMessage.find j['args'][0]
          assert tm

          assert_equal channel.id, tm.channel_id
          assert_match generate_text(incoming_message), normalized(generate_text(tm))
        end
      end
    end
  end
end
