module DataApi
  class RequestAuthenticationsController < BaseController
    skip_before_action :authorize!

    def create
      if requester.present? && create_action.call
        response_data = {}
        render json: response_data, status: :created
      else
        render json: {}, status: error_status_code
      end
    end

    private

      def error_status_code
        if requester.blank? || requester_business.blank?
          :payment_required
        else
          :unprocessable_entity
        end
      end

      def create_action
        @create_action ||= if requester.present?
          ::ApiActions::AuthenticationMessage::Send.new( requester, AuthenticationCode.new(person: requester), requester_channel )
        end
      end

      def requester_business
        Business.administered_by( requester ).last
      end

      def requester
        @requester ||= Person.where( mobile: params[:mobile] ).first
      end

      def requester_channel
        requester.channels.where( topic: ::Channel::ROOT_TOPIC ).last || requester.channels.where( topic: ::Channel::INVITE_TOPIC ).last || new_invite_channel
      end

      def new_invite_channel
        ::Channel.new business: requester_business, topic: ::Channel::INVITE_TOPIC, people: [ requester ]
      end
  end
end
