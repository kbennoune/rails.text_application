module ApiActions
  module Message
    class Send
      include ApiActions::Action
      attr_reader :channel, :message_text, :message_from, :message_sender, :message_media

      def initialize(channel, message_text, message_from, message_sender, message_media=[])
        @channel = channel
        @message_text = message_text
        @message_from = message_from
        @message_sender = message_sender
        @message_media = message_media
      end

      def messages
        [ message ]
      end

      def message
        @message ||= text_message_out(
          message_keys: t('recipients', message: message_text, sender: message_sender.display_name),
          channel: channel, media: message_media,
          original_sender: message_sender, original_from: message_from,
          message_from: message_from, sender: message_sender
        )
      end

      def call
        message.save!
      end
    end
  end
end
