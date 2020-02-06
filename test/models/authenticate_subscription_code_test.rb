require 'test_helper'

class AuthenticateSubscriptionCodeTest < ActiveSupport::TestCase
  test "a new record will have a random code" do
    assert_match /\d{6}/, AuthenticateSubscriptionCode.new.code
  end

  test "authenticates a related subscription" do
    subscription = Subscription.new
    code = 6.times.map{ SecureRandom.random_number(10) }.join
    mobile = PhoneNumber.new('9191234567')
    model = AuthenticateSubscriptionCode.create!( mobile: mobile, code: code, subscription: subscription )
    retrieved = AuthenticateSubscriptionCode.authenticate(mobile, code)

    assert_equal model, retrieved
    assert_equal model.subscription, retrieved.subscription
  end
end
