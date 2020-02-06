module ChannelTopics
  module Participant
    class List < ChannelTopics::Processor
      include ChannelTopics::PeopleManager

      def call
        list_message.save!
      end

      def list_message
        @list_message ||= text_message_out to: :sender, message_keys: list_text
      end

      def list_text
        t(subject_channel.topic, business_name: subject_channel.business.display_name, people: subject_channel.people.map{|p| [p.display_name, p.mention_code( within: subject_channel )].join("\n") }  )
      end

      def subject_channel
        @subject_channel ||= if message_text.match(/\s+all(\s|$)/)
          root_channel
        else
          channel
        end
      end
    end
  end
end
