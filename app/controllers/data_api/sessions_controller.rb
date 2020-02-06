module DataApi
  class SessionsController < BaseController
    skip_before_action :authorize!

    def create
      # render json: { id: params[:id] }
      authentication = ApiRequest::Authenticate.new(params[:mobile], params[:code])

      if authentication.valid?
        businesses = Business.administered_by( authentication.person )

        render json: { token: authentication.token, business_id: businesses.last.try(:id) }
      else
        render json: { error: 'Authentication Failed'}, status: :unauthorized
      end
    end
  end
end
