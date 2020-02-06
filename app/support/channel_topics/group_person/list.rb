module ChannelTopics
  module GroupPerson
    class List < ChannelTopics::Processor
      def call
        if group.present?
          list_message.save!
        else
          failed_missing_group_message.save!
        end
      end

      def list_message
        @list_message ||= text_message_out to: :sender, message_keys: list_text
      end

      def failed_missing_group_message
        @failed_missing_group_message ||= text_message_out to: :sender, message_keys: t('failed.missing_group')
      end

      def list_text
        t('list', business_name: channel_business.display_name, group: group.name, people: group.people.map(&:display_name) )
      end

      def group
        @group ||= groups.first
      end

      def groups
        message_text.scan(ChannelTopics::PeopleManager::NAMES_REGEX).map{ |match|
          Trigram.channel_matches_for( root_channel, match ).where( owner_type: 'TextGroup' ).first.try(:owner)
        }.compact
      end
    end
  end
end
