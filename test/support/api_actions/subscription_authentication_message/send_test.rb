require 'test_helper'

module ApiActions
  module SubscriptionAuthenticationMessage
    class SendTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def subscription
        @subscription ||= begin
          Subscription.new
        end
      end

      def authenticate_subscription_code
        @authenticate_subscription_code ||= begin
          AuthenticateSubscriptionCode.new( code: '666666', mobile: '9192223434', subscription: subscription )
        end
      end

      def application_phone_number
        ApplicationPhoneNumber.last
      end

      test 'it saves the authentication code' do
        api_action = Send.new( subscription, authenticate_subscription_code, application_phone_number )

        assert api_action.call
        assert authenticate_subscription_code.persisted?
        assert subscription.persisted?
        assert api_action.authenticate_subscription_code_message.persisted?
        assert_equal authenticate_subscription_code.code, api_action.authenticate_subscription_code_message.message_generator_keys.dig(0,'values', 'code')
      end

      test 'it will not send a message if there is a problem saving' do
        api_action = Send.new( subscription, authenticate_subscription_code, application_phone_number )

        authenticate_subscription_code.stub(:valid?, false) do
          assert !api_action.call
          assert !authenticate_subscription_code.persisted?
          assert !subscription.persisted?
          assert !api_action.authenticate_subscription_code_message.persisted?
        end
      end

      test 'validating subscriptions' do
        code_with_invalid_number = AuthenticateSubscriptionCode.new( code: '666666', mobile: '919222', subscription: subscription )

        Send.new( subscription, code_with_invalid_number, application_phone_number ).tap do |api_action|
          assert !api_action.valid?
          assert_match "is an invalid number", api_action.errors.to_h[:mobile]
        end

        code_starting_with_one = AuthenticateSubscriptionCode.new( code: '666666', mobile: '19192223333', subscription: subscription )
        Send.new( subscription, code_starting_with_one, application_phone_number ).tap do |api_action|
          assert api_action.valid?
        end

        code_starting_without_one = AuthenticateSubscriptionCode.new( code: '666666', mobile: '9192223333', subscription: subscription )
        Send.new( subscription, code_starting_without_one, application_phone_number ).tap do |api_action|
          assert api_action.valid?
        end

        code_starting_with_plus = AuthenticateSubscriptionCode.new( code: '666666', mobile: '+19192223333', subscription: subscription )
        Send.new( subscription, code_starting_with_plus, application_phone_number ).tap do |api_action|
          assert api_action.valid?
        end

        code_with_formatting = AuthenticateSubscriptionCode.new( code: '666666', mobile: '(919) 222-3333', subscription: subscription )
        Send.new( subscription, code_with_formatting, application_phone_number ).tap do |api_action|
          assert api_action.valid?
        end
      end
    end
  end
end
