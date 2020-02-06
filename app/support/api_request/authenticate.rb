module ApiRequest
  class Authenticate
    attr_reader :errors, :code, :phone_number, :expiration_length

    def initialize(phone_number, code, errors: nil, expiration_length: 1.month)
      @phone_number = phone_number
      @code = code
      @errors = errors || ActiveModel::Errors.new(self)
      @expiration_length = expiration_length
    end

    def valid?
      person.present?
    end

    def person
      @person ||= begin
        AuthenticationCode.authenticate(phone_number, code)
      end
    end

    def token
      if valid?
        JsonToken.encode(payload: {person_id: person.id}, expires_in: expiration_length)
      end
    end
  end
end
