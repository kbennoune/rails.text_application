module DataApi
  class AuthenticateSubscription
    attr_reader :code, :errors, :mobile
    include ActiveModel::Validations

    validates_each :code do |model, attr, value|
      model.errors.add(attr, 'is invalid or expired') unless model.authenticated_subscription
    end

    def initialize(mobile, code, errors: ActiveModel::Errors.new(self))
      @mobile = mobile
      @code = code
      @errors = errors
    end

    def subscription
      authenticated_subscription
    end

    def authenticated_subscription
      authenticate_subscription_code && authenticate_subscription_code.subscription
    end

    def authenticate_subscription_code
      @authenticate_subscription_code ||= AuthenticateSubscriptionCode.authenticate(mobile, code)
    end
  end
end
