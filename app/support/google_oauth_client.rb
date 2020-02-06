module GoogleOauthClient
  def google_oauth_client(identity)
    Signet::OAuth2::Client.new(
      access_token: identity.oauth_token,
      expires_at: identity.oauth_expires_at,
      refresh_token: identity.oauth_refresh_token,
      token_credential_uri: 'https://www.googleapis.com/oauth2/v3/token',
      client_id: Rails.application.secrets.google[:client_id],
      client_secret: Rails.application.secrets.google[:client_secret]
    )
  end
end
