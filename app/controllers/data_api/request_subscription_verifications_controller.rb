module DataApi
  class RequestSubscriptionVerificationsController < BaseController
    skip_before_action :authorize!

    # mobile,
    # productIdentifier,
    # transactionIdentifier,
    # transactionReceipt,
    # transactionDate

    def create
      if create_action.call
        response_data = { mobile: authenticate_subscription_code.mobile }
        render json: response_data, status: :created
      else
        render json: { errors: create_action.errors.messages }, status: error_status_code
      end
    end

    private

      def create_action
        @create_action ||= begin
          ::ApiActions::SubscriptionAuthenticationMessage::Send.new( subscription, authenticate_subscription_code, application_phone_number )
        end
      end

      def error_status_code
        # SHOULD CHECK SUBSCRIPTION HERE
        # if requester.blank? || requester_business.blank?
        #   :payment_required
        # else
          :unprocessable_entity
        # end
      end


      def subscription
        @subscription ||= Subscription.where(subscription_params).first || Subscription.new( subscription_params )
      end

      def authenticate_subscription_code
        @authenticate_subscription_code ||= AuthenticateSubscriptionCode.new( {subscription: subscription, mobile: mobile_param } )
      end

      def subscription_params
        params.permit(:product_identifier, :transaction_identifier, :transaction_receipt, :transaction_date)
      end

      def mobile_param
        params.require(:mobile)
      end

      def application_phone_number
        ApplicationPhoneNumber.last
      end
  end
end
