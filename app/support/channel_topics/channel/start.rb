module ChannelTopics
  module Channel
    class Start < ChannelTopics::Processor
      include UnicodeFormatting::Helper
      delegate :channel_message, :channel_starter_message, :recipients, to: :action

      def call
        action.call
      end

      def action
        @action ||= begin
          ::ApiActions::Channel::Start.new( message_sender, message_from, included_recipients, started_channel, parser_message, parent_message: message, error_handler: lambda{ error_message.save! }  )
        end
      end

      def error_message
        @error_message ||= text_message_out to: :sender, message_keys: error_message_text
      end

      def started_channel
        @started_channel ||= ChannelForRecipients.new(
          new_channel_topic,
          sender: message_sender, business_id: channel.business_id,
          started_by: message_sender, text_groups: parsed_groups,
          receivers: channel_receivers
        ).channel
      end

      def channel_receivers
        [message_sender, included_recipients].flatten.compact
      end

      def error_message_text
        t('error')
      end

      def included_recipients
        @included_recipients ||= (parsed_recipients + parsed_groups.map(&:people).flatten).uniq
      end

      def parsed_recipients
        @parsed_recipients ||= parser.recipients.find_all{|r| r.kind_of?(::Person)}
      end

      def parsed_groups
        @parsed_groups ||= parser.recipients.find_all{|r| r.kind_of?(::TextGroup)}
      end

      def text_groups
        root_channel.business.text_groups
      end

      def parser_message
        @parser_message ||= parser.message
      end

      def new_channel_topic
        ::Channel::CHAT_TOPIC
      end

      def parser
        @parser ||= ChannelMessageParser.new(message.message_text) do |potential_recipients|
          potential_recipients.map{ |name|
            match = Trigram.channel_matches_for(channel, name).first
            if match && (match.matches.to_f/match.score.to_f > 0.25)
              [ name, match.owner ]
            end
          }.compact.to_h
        end
      end

      def possible_recipient_scopes
        [ root_channel.business.text_groups, root_channel.people ]
      end

    end
  end
end
