module ChannelTopics
  module Participant
    class Remove < ChannelTopics::Processor
      include ChannelTopics::PeopleManager

      def call
        ::Channel.transaction do
          # send a response and an error message
          if people_to_remove.present?
            channel.people.destroy people_to_remove

            send_success_messages
          else
            failed_remove_message.save!
          end
        end
      end

      def send_success_messages
        successful_remove_message.save!
        notify_removed_message.save!
      end

      def people_to_remove
        included_people
      end

      def message_name_portion
        super.gsub(/#?[Rr]emove/,'')
      end

      def notify_removed_message
        text_message_out message_from: message_to.first, to: people_to_remove.map(&:mobile), to_people: people_to_remove.map{|person| person.slice(:id, :mobile, :name) }, message_keys: notify_removed_message_text, channel: nil
      end

      def successful_remove_message
        text_message_out to: :sender, message_keys: successful_remove_message_text
      end

      def failed_remove_message
        text_message_out to: :sender, message_keys: failed_remove_message_text
      end

      def notify_removed_message_text
        t('success.removed', sender: message_sender.display_name )
      end

      def successful_remove_message_text
        t('success.sender', sender: message_sender.display_name, removed_people: people_to_remove.map(&:display_name))
      end

      def failed_remove_message_text
        t('failed.sender')
      end
    end
  end
end
