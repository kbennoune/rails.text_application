module ChannelTopics
  module GroupPerson
    class Add < ChannelTopics::Processor
      include ChannelTopics::PeopleManager

      GROUP_LINE_REGEX = ChannelTopics::Person::Create::GROUP_LINE_REGEX
      GROUP_REGEX = ChannelTopics::Person::Create::GROUP_REGEX
      WORD_BREAK_PUNCTUATION = ChannelTopics::Person::Create::WORD_BREAK_PUNCTUATION

      def action
        @action ||= begin
          ::ApiActions::GroupPerson::Add.new(groups, included_people)
        end
      end

      def call
        if group_names.present? && included_people.present? && action.call
          successful_add_message.save!
        else
          failed_add_message.save!
        end
      end

      def successful_add_message
        text_message_out to: :sender, message_keys: successful_add_message_text
      end

      def failed_add_message
        text_message_out to: :sender, message_keys: failed_add_message_text
      end

      def successful_add_message_text
        t('success.sender', groups: groups.map(&:name), people: included_people.map(&:display_name))
      end

      def failed_add_message_text
        case
        when group_names.present?
          t('failed.missing_people', groups: group_names)
        when included_people.present?
          t('failed.missing_groups', people: included_people.map(&:display_name))
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
        group_names.map do |name|
          existing_groups.find{|existing| existing.name == name } || ::TextGroup.new( name: name, business_id: channel.business_id, created_by_person: message_sender )
        end
      end

      def group_names
        message_text_group_lines.join.gsub(' and ',', ').match( GROUP_REGEX ).try(:[], 2).to_s.split(/[#{ WORD_BREAK_PUNCTUATION }]/).map(&:strip).find_all(&:present?)
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
