module ChannelTopics
  module Group
    class List < ChannelTopics::Processor
      def call
        list_message.save!
      end

      def list_message
        @list_message ||= text_message_out to: :sender, message_keys: list_text

        # TextMessage.out(
        #   message_text: list_text, channel: channel,
        #   original_from: message_from, to: message_from
        # )
      end

      def list_text
        t('list', business_name: channel_business.display_name, groups: channel_business.text_groups.map(&:name))
      end
    end
  end
end
