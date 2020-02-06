class SessionsController < ApplicationController
  attr_reader :new_identity
  helper_method :new_identity

  def create
    if request.env["omniauth.auth"] && (@new_identity = identity_from_omniauth(request.env["omniauth.auth"], current_user)).persisted?
      create_callback(new_identity)
      # render 'sessions/new'
      redirect_to created_url
    else
      render 'sessions/new'
    end
  end

  def destroy
    session[:admin_user_id] = nil
    session[:user_id] = nil
    redirect_to '/'
  end

  def created_url
    '/'
  end

  private
    def create_callback(new_identity)
    end

    def identity_query(auth,user)
      # Only one user can have the same
      # identity, typically when the user
      # is one to one with the remote provider
      { provider: auth.provider, uid: auth.uid  }
    end

    def identity_from_omniauth(auth, user)
      Identity.where(identity_query(auth, user)).first_or_initialize.tap do |identity|
        set_identity_params(identity, auth)

        identity.user ||= (user || User.new)
        identity.save!
      end
    end

    def set_identity_params(identity, auth)
      identity.provider = auth.provider
      identity.uid = auth.uid
      identity.name = auth.info.name
      identity.oauth_token = auth.credentials.token
      identity.email = auth.info.email

      if auth.credentials.expires_at.present?
        identity.oauth_expires_at = Time.at(auth.credentials.expires_at)
      end

      if auth.credentials.scope.present?
        identity.scope = auth.credentials.scope
      end
    end
end
