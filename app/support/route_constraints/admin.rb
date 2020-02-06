module RouteConstraints
  class Admin
    def matches?(request)
      return true if Rails.env.development?
      
      return false unless request.session[:user_id]
      # user = User.find request.session[:user_id]
      # user && user.admin?

      request.session[:user_id].to_i == 1 ||
        request.session[:admin_user_id].to_i == 1
    end
  end
end
