class AuthenticationCode < ApplicationRecord
  belongs_to :person
  attribute :code, :string, default: ->{ random_code }
  attribute :expires_at, :datetime, default: ->{ Time.now + expiration_length }
  
  class << self
    def expiration_length
      1.hour
    end

    def random_code
      6.times.map{ SecureRandom.random_number(10) }.join
    end

    def authenticate(phone_number, code)
      joins(:person).where(
        code: code, people: { mobile: phone_number }
      ).where( arel_table[:expires_at].gt(Time.now) ).first.try(:person)
    end
  end
end
