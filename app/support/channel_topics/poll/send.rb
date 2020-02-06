module ChannelTopics
  module Poll
    class Send < ChannelTopics::Processor

      def call
        text_message_out( message_attributes ).save!
      end

      def message_attributes
        if channel_started_by_person == message_sender
          base_message_attributes.merge( message_keys: t('recipients', message: message.message_text, sender: message_sender.display_name) )
        else
          base_message_attributes.merge( message_keys: t('starter', message: message.message_text, sender: message_sender.display_name), to: channel_started_by_person.mobile )
        end
      end

      def base_message_attributes
        {
          channel: channel, media: message_media,
          original_sender: message_sender, original_from: message_from,
          message_from: message_from
        }
      end

    end
  end
end
