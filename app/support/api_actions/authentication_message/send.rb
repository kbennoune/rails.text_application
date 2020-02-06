module ApiActions
  module AuthenticationMessage
    class Send
      include ApiActions::Action

      attr_reader :requester, :authentication_code, :channel

      def initialize( requester, authentication_code, channel )
        @requester = requester
        @authentication_code = authentication_code
        @create_invite_channel = channel.blank?
        @channel = channel
      end

      def create_invite_channel?
        @create_invite_channel
      end

      def call
        begin
          ::AuthenticationCode.transaction do
            channel.save! if save_channel?
            authentication_code.save!
            authentication_code_message.save!
            @success = true
          end
        rescue ActiveRecord::RecordInvalid => exception
          @exception = exception
          @success = false
        end

        @success
      end

      def message_from
        requester.mobile
      end

      def authentication_code_message
        @authentication_code_message ||= text_message_out to: message_from, channel: channel, message_keys: authentication_code_message_text
      end

      def save_channel?
        ( channel.topic == ::Channel::INVITE_TOPIC ) && channel.new_record?
      end

      def authentication_code_message_text
        t('', code: authentication_code.code )
      end
    end
  end
end
