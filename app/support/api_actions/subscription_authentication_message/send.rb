module ApiActions
  module SubscriptionAuthenticationMessage
    class Send
      include ApiActions::Action
      include ActiveModel::Validations
      attr_reader :subscription, :authenticate_subscription_code, :application_phone_number

      validates_format_of :mobile, with: /\d{10}/, message: "is an invalid number"

      def initialize( subscription, authenticate_subscription_code, application_phone_number, errors: ActiveModel::Errors.new(self) )
        @subscription = subscription
        @authenticate_subscription_code = authenticate_subscription_code
        @application_phone_number = application_phone_number
      end

      def mobile
        PhoneNumber.new( authenticate_subscription_code.mobile )
      end

      def call
        if valid?
          do_call
        end
      end

      def do_call
        begin
          ::AuthenticateSubscriptionCode.transaction do
            authenticate_subscription_code.save!
            authenticate_subscription_code_message.save!

            @success = true
          end
        rescue ActiveRecord::RecordInvalid => exception
          @exception = exception
          @success = false
        end

        @success
      end

      def subscriber_number
        authenticate_subscription_code.mobile
      end

      def message_from
        subscriber_number
      end

      def authenticate_subscription_code_message
        @authenticate_subscription_code_message ||= text_message_out to: subscriber_number, message_keys: message_text, message_from: application_phone_number.number
      end

      def message_text
        t('', code: authenticate_subscription_code.code )
      end
    end
  end
end
