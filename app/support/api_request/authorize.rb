module ApiRequest
  class Authorize
    attr_reader :errors
    HEADER_FORMAT = /(?<=Bearer ).*/

    def initialize(headers={}, errors: nil, model: Person, token_key: :person_id)
      @headers = headers
      @errors = errors || ActiveModel::Errors.new(self)
      @model = model
      @token_key = token_key
    end

    def call
      if @called
        @record
      else
        @called = true
        @record ||= get_record
      end
    end

    def record
      @record || call
    end

    def token
      @token ||= (call && ( decoded_auth_token || {} ))
    end

    private

      attr_reader :headers, :model, :token_key

      def get_record
        if decoded_auth_token
          model.find(decoded_auth_token[token_key])
        end
      end

      def decoded_auth_token
        @decoded_auth_token ||= JsonToken.decode(http_auth_header).tap do |decoded|
          errors.add(:token, 'Invalid token') if decoded.blank?
        end
      end

      def http_auth_header
        if headers['HTTP_AUTHORIZATION'].present?
          headers['HTTP_AUTHORIZATION'].scan(HEADER_FORMAT).first
        else
          errors.add(:token, 'Missing token') && nil
        end
      end
  end
end
