class AuthenticateSubscriptionCode < ApplicationRecord
  belongs_to :subscription
  attribute :code, :string, default: ->{ random_code }
  attribute :expires_at, :datetime, default: ->{ Time.now + expiration_length }
  attribute :mobile, :phone_number

  class << self
    def expiration_length
      1.day
    end

    def random_code
      6.times.map{ SecureRandom.random_number(10) }.join
    end

    def authenticate(phone_number, code)
      joins(:subscription).where(
        code: code, mobile: phone_number
      ).where( arel_table[:expires_at].gt(Time.now) ).first
    end
  end
end
