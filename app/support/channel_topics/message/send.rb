module ChannelTopics
  module Message
    class Send < ChannelTopics::Processor

      def call
        action.call
      end

      def action
        @action ||= begin
          ::ApiActions::Message::Send.new( channel, message.message_text, message_from, message_sender, message_media )
        end
      end

    end
  end
end
