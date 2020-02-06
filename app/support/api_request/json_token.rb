module ApiRequest
  module JsonToken
    def encode(payload: {}, expires_at: nil, expires_in: 24.hours)
      if ( expires = (expires_at || expires_in.try(:from_now)) )
        payload[:exp] = expires.to_i
      end

      JWT.encode(payload, secret)
    end

    def decode(token)
      body = JWT.decode(token, secret)[0]
      HashWithIndifferentAccess.new body
    rescue
      nil
    end

    def secret
      Rails.application.secrets.secret_token_base
    end

    extend self
  end
end
