module ChannelTopics
  module Person
    class Remove < ChannelTopics::Processor
      include ChannelTopics::PeopleManager

      def call
        remove_action = ::ApiActions::Person::Remove.new( root_channel, included_people, message_sender, message, channel_business )

        if remove_action.call
          successful_remove_message.save!
        else
          failed_remove_message.save!
        end
      end

      # This should be less forgiving of misspellings
      def fuzzy_match_cutoff
        0.3
      end

      def successful_remove_message
        text_message_out to: :sender, message_keys: successful_remove_text
      end

      def failed_remove_message
        text_message_out to: :sender, message_keys: failed_remove_text
      end

      def successful_removed_message
        text_message_out to: included_people.map(&:mobile), message_keys: successful_removed_text, channel: nil
      end

      def successful_removed_text
        t('success.removed', business_name: channel_business.display_name, sender: message_sender.display_name )
      end

      def successful_remove_text
        t('success.sender', removed_people: included_people.map(&:display_name) )
      end

      def failed_remove_text
        t('failed.sender')
      end
    end
  end
end
