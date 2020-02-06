module ChannelTopics
  module Channel
    class Help < ChannelTopics::Processor

      def call
        help_message.save!
      end

      def help_message
        @help_message ||= text_message_out to: :sender, message_keys: help_text
      end

      def help_text
        t(channel_topic, room_channels_and_numbers: room_channels_and_numbers)
      end

      def room_channels_and_numbers
        room_channel_results = ::Channel.joins( :text_groups, channel_people: :application_phone_number ).where( channels: { business_id: channel_business.id }, channel_people: { person_id: message_sender.id } ).group('channels.id', 'application_phone_numbers.number').pluck( 'channels.id', 'application_phone_numbers.number', 'GROUP_CONCAT(text_groups.name SEPARATOR "||")' )
        room_channel_results.map{|id, number, groups|  [ groups.to_s.split('||').compact.map(&:titleize).to_sentence, "sms:#{PhoneNumber.new(number).to_s(:url)}" ]}
      end
    end
  end
end
