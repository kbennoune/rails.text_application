OmniAuth.config.logger = Rails.logger

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook, Rails.application.secrets.facebook[:app_id], Rails.application.secrets.facebook[:app_secret]
end

# prompt consent is required to ensure that google reissues
# a refresh token every time. 
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, Rails.application.secrets.google[:client_id], Rails.application.secrets.google[:client_secret],
    name: :google, prompt: :consent, skip_jwt: true, include_granted_scopes: true, access_type: 'offline', scope: 'https://www.googleapis.com/auth/calendar.readonly,https://www.googleapis.com/auth/userinfo.email'
end
