module ChannelTopics
  module Participant
    class RemoveSelf < ChannelTopics::Participant::Remove

      def people_to_remove
        # send a message notifying the user that they've been removed
        [ message_sender ]
      end

      def send_success_messages
        successful_remove_message.save!
      end

      def successful_remove_message
        @successful_remove_message ||= text_message_out to: [ message_sender.mobile ], to_people: [ message_sender.slice(:id, :mobile, :name) ],message_from: message_to.first, message_keys: successful_remove_message_text, channel: nil
      end

      def successful_remove_message_text
        t('success')
      end
    end
  end
end
