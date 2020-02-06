module ChannelTopics
  module GroupPerson
    class Remove < ChannelTopics::Processor
      include ChannelTopics::PeopleManager

      GROUP_LINE_REGEX = Regexp.new( ChannelTopics::Person::Create::GROUP_LINE_REGEX.to_s.gsub('[Tt]o','[Ff]rom') )
      GROUP_REGEX = Regexp.new( ChannelTopics::Person::Create::GROUP_REGEX.to_s.gsub('[Tt]o','[Ff]rom') )
      WORD_BREAK_PUNCTUATION = ChannelTopics::Person::Create::WORD_BREAK_PUNCTUATION

      def call
        if group_names.present? && included_people.present? && remove_action.call
          successful_remove_message.save!
        else
          failed_remove_message.save!
        end
      end

      def remove_action
        @remove_action ||= ApiActions::GroupPerson::Remove.new( groups, included_people )
      end

      def successful_remove_message
        text_message_out to: :sender, message_keys: successful_remove_message_text
      end

      def failed_remove_message
        text_message_out to: :sender, message_keys: failed_remove_message_text
      end

      def successful_remove_message_text
        t('success.sender', removed_people: included_people.map(&:display_name), removed_from_groups: group_names, group_descriptor: group_names.size.eql?(1) ? 'group' : 'groups')
      end

      def failed_remove_message_text
        case
        when group_names.present?
          t('failed.missing_people', groups: group_names )
        when included_people.present?
          t('failed.missing_groups', people: included_people.map(&:display_name) )
        else
          t('failed.missing_groups_and_people')
        end
      end

      def existing_groups
        @existing_groups ||= TextGroup.where(
          business_id: channel.business_id,
          name: group_names
        )
      end

      def groups
        existing_groups
      end

      def group_names
        message_text_group_lines.join.gsub(' and ',', ').match( GROUP_REGEX ).try(:[], 2).to_s.split(/[#{WORD_BREAK_PUNCTUATION}]/).map(&:strip).find_all(&:present?)
      end

      def message_text_group_lines
        @message_text_group_lines ||= message_text.scan(GROUP_LINE_REGEX)
      end

      def message_name_portion
        message_text_group_lines.inject( message_text ) do |acc, line|
          acc.gsub( line , '' )
        end
      end

    end
  end
end
