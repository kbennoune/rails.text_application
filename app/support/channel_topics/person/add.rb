module ChannelTopics
  module Person
    class Add < ChannelTopics::Processor
      # include ::ChannelTopics::ContactInfoHelper


      def call
        ::Person.transaction do
          contacts_from_definitions.map(&:save!)

          # root_channel

          # contacts_from_definitions.map do |contact|
          #   response_number = ApplicationPhoneNumber.next_available(contact, message_channel, ChannelPerson.new(channel: message_channel, person: contact))
          #
          #   TextMessage.new to: contact.mobile, message_from: response_number.number, message_keys:
          # end

          response_message.save!
        end
      end

      def response_message
        @response_message ||= text_message_out channel: invite_channel, message_keys: t('verify', sender: message_sender.display_name, busines_name: channel_business.display_name )
      end

      def contacts_from_definitions
        @contacts_from_definitions ||= begin
          existing_people = ::Person.where( mobile: contact_definitions.map{|hsh| hsh[:mobile]}.compact )
          builder = ApiActions::Person::Builder.new( channel_business, contact_definitions, existing_people: existing_people, groups_to_add: groups, invite_channel: invite_channel )
          builder
        end
      end

      def group_part
        message_text.match(/#invite to [^:\n]*/)[0]
      end

      def contact_part
        # Add 1 to the initial index to remove the separator
        initial_index = 1 + message_text.index( group_part ) + group_part.length

        message_text[initial_index..-1]
      end

      def contact_definition_strings
        contact_part.scan(/\p{Ps}([^\p{Pe}]*)\p{Pe}/).map{|match| match.respond_to?(:first) ? match.first : match }
      end

      def contact_definitions
        contact_definition_strings.map do |str|
          number = str.scan(/(?<=^|[^\d])[+\d][\d\(\)\.-]+\d(?=[^\d]|$)/).first
          name = str.sub(number, '').split(' to ').first.strip

          {
            name: name,
            mobile: number
          }
        end
      end

      def invite_channel
        @invite_channel ||= begin
          ::Channel.new( topic: ::Channel::INVITE_TOPIC, business: channel.business, started_by_person: message.sender )
        end
      end

      def group_names
        @group_names ||= group_part.gsub(' and ',', ').match( ChannelTopics::Person::Create::GROUP_REGEX )
          .try(:[], 2).to_s.split(/[#{ChannelTopics::Person::Create::WORD_BREAK_PUNCTUATION}]/)
          .map(&:strip).find_all(&:present?)
      end

      def groups
        @groups ||= begin
          existing_groups = TextGroup.where( business_id: channel.business_id, name: group_names)
          group_names.map do |name|
            existing_groups.find{|existing| existing.name == name } || ::TextGroup.new( name: name, business: channel.business, created_by_person: message_sender )
          end
        end
      end
    end
  end
end
