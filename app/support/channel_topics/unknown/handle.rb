module ChannelTopics
  module Unknown
    class Handle < ::ChannelTopics::Processor
      include UnicodeFormatting::Helper

      def call
        # find if there is a user with that phone number
        text_message = text_message_out to: :sender, message_keys: response_text

        if text_message.channel.blank?
          text_message[:message_from] = message_to.first
        end

        text_message.save!
      end

      def response_text
        if message_sender.present?
          response_text_for_registered
        else
          response_text_for_unregistered
        end
      end

      def response_text_for_unregistered
        t('unregistered')
      end

      def response_text_for_registered
        t('registered')
      end
    end
  end
end
