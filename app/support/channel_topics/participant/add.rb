module ChannelTopics
  module Participant
    class Add < ChannelTopics::Processor
      include ChannelTopics::PeopleManager

      def call
        ::Channel.transaction do
          if included_people.present?
            channel.people << included_people

            add_person_message.save!
            added_person_message.save!
          else
            failed_add_message.save!
          end
        end
      end

      def added_person_message
        text_message_out to: included_people.map(&:mobile), to_people: included_people.map{|person| person.slice(:id, :mobile, :name) }, message_keys: added_person_text
      end

      def add_person_message
        text_message_out to: :sender, message_keys: add_person_text
      end

      def failed_add_message
        text_message_out to: :sender, message_keys: failed_add_text
      end

      def added_person_text
        t('success.added', adder_name: message_sender.display_name)
      end

      def add_person_text
        t('success.other', added_names: included_people.map(&:display_name))
      end

      def failed_add_text
        t('failed.sender')
      end
    end
  end
end
