module ApiActions
  module Channel
    class Start
      include ApiActions::Action

      attr_reader :message_sender, :additional_recipients, :recipients, :channel, :message, :message_from, :parent_message, :error_handler

      # message_sender is a person
      # message_from is a mobile
      # additional_recipients is an array of people
      # channel is a channel
      # message is a string
      def initialize( message_sender, message_from, additional_recipients, channel, message, parent_message: nil, error_handler: lambda{ }  )
        @message_sender = message_sender
        @additional_recipients = additional_recipients
        @recipients = [ message_sender, additional_recipients ].flatten.uniq.compact
        @channel = channel
        @message = message
        @parent_message = parent_message
        @message_from = message_from
        @error_handler = error_handler
      end

      def channel_can_be_started?
        @additional_recipients.present?
      end

      def call
        # create a channel
        ::Channel.transaction do
          if channel_can_be_started?
            if save_channel?
              channel.save!
              # Add users channels with phone numbers
              recipients.each do |recipient|
                recipient.channels << channel
              end
            end

            # Send the initial text
            channel_message.save!
            channel_starter_message.save!
            @success = true
          else
            error_handler.call
            @success = false
          end
        end
      end

      def messages
        [ channel_message, channel_starter_message ]
      end

      def success?
        @success
      end

      def channel_message
        @channel_message ||= text_message_out message_from: message_from, sender: message_sender, message_keys: new_text_message_text, channel: channel, header_addendum_key: t('success.included_header_addendum'), hide_header_description: true
      end

      def channel_starter_message
        @channel_starter_message ||= text_message_out to: :sender, channel: channel, message_keys: channel_starter_message_text, header_addendum_key: t('success.sender_header_addendum')
      end

      def new_text_message_text
        t('success.included', sender: message_sender.display_name, people: recipients.map(&:display_name), message: message)
      end

      def channel_starter_message_text
        t('success.sender', message: message, people: additional_recipients.map(&:display_name) )
      end

      def save_channel?
        channel.new_record?
      end
    end
  end
end
