module DataApi
  class BaseController < ApplicationController
    skip_before_action :verify_authenticity_token

    before_action :authorize!

    private
      def authorize!
        if !authorized?
          response.headers['WWW-Authenticate'] = "Basic realm=#{domain}"
          render json: {}, status: :unauthorized
        end
      end

      def authorized?
        current_person.present? && ( current_business.present? ? current_business.administered_by?( current_person ) : true )
      end

      def domain
        host = Rails.application.config.x.data_host
        scheme = Rails.application.config.x.data_host_protocol
        Addressable::URI.new( host: host, scheme: scheme).to_s
      end

      def authorization
        @authorization ||= ApiRequest::Authorize.new(request.headers)
      end

      def current_person
        authorization.record
      end

      def current_business
        if params[:business_id]
          @current_business ||= Business.find( params[:business_id] )
        end
      end
  end
end
