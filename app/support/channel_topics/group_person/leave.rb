module ChannelTopics
  module GroupPerson
    class Leave < ChannelTopics::GroupPerson::Remove

      def included_people
        [ message_sender ]
      end

      def groups
        if existing_groups.blank? && message_sender_channel_text_group.present?
          message_sender_channel_text_group
        else
          existing_groups
        end
      end

      def group_names
        if (names = super).present?
          names
        elsif message_sender_channel_text_group.present?
          [message_sender_channel_text_group.name]
        else
          names
        end
      end

      def message_sender_channel_text_group
        channel.channel_people.find{|cp| cp.person_id == message_sender.id }.try(:added_from_text_group)
      end

    end
  end
end
