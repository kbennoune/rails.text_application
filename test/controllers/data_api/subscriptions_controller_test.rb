require 'test_helper'
require 'controllers/data_api/controller_test_helper.rb'

module DataApi
  class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
    def code
      '$ekret'
    end

    def mobile
      '2223334567'
    end

    def transaction_identifier; 't3@nsact1on-id'; end
    define_method(:product_identifier){ 'pr0duct-id' }
    define_method(:person_name){ @person_name ||= 'New User' }
    define_method(:business_name){ 'New Business Name' }
    define_method(:stored_subscription_code){ @stored_subscription_code ||= AuthenticateSubscriptionCode.new( subscription: stored_subscription ) }
    define_method(:stored_subscription){ @stored_subscription ||= Subscription.new( ) }

    def authenticate_action(valid_mobile, valid_code, response)
      ->(phone_number, secret_code){ phone_number == valid_mobile && secret_code == valid_code &&  response}
    end

    test 'linking a new subscription for a user' do


      AuthenticateSubscriptionCode.stub(:authenticate, authenticate_action(mobile, code, stored_subscription_code) ) do
        post '/api/subscriptions', params: { mobile: mobile, code: code, name: person_name, business_name: business_name, transaction_identifier: transaction_identifier, product_identifier: product_identifier }, as: :json
      end

      json_response = JSON.parse( response.body )
      response_token = json_response['token']

      assert_business_exists( json_response['business_id'], with_name: business_name )
      token_payload = ApiRequest::JsonToken.decode( response_token )
      assert_person_exists( token_payload['person_id'], with_mobile: mobile, with_name: person_name )
    end

    def assert_person_exists(person_id, with_mobile: nil, with_name: nil)
      new_person = Person.where( id: person_id ).first
      assert new_person

      if with_mobile
        assert_equal PhoneNumber.new(with_mobile), new_person.mobile
      end

      if with_name
        assert_equal with_name, new_person.name
      end
    end

    test 'linking an existing user' do
      existing_person = Person.create!( name: 'An existing person', mobile: mobile )

      AuthenticateSubscriptionCode.stub(:authenticate, authenticate_action(mobile, code, stored_subscription_code) ) do
        post '/api/subscriptions', params: { mobile: mobile, code: code, name: person_name, business_name: business_name, transaction_identifier: transaction_identifier, product_identifier: product_identifier }, as: :json
      end
      json_response = JSON.parse( response.body )
      response_token = json_response['token']

      token_payload = ApiRequest::JsonToken.decode( response_token )
      tokenized_person = Person.where( id: token_payload['person_id'] ).first
      assert_equal existing_person, tokenized_person

      assert_business_exists( json_response['business_id'], with_name: business_name )
    end

    test 'linking an existing person with an existing business' do
      existing_person = Person.create!( name: 'An existing person', mobile: mobile )
      existing_business = Business.create!( name: 'An existing Business' )

      subscription_code_for_existing_business = AuthenticateSubscriptionCode.new( subscription: Subscription.new( business: existing_business ) )

      AuthenticateSubscriptionCode.stub(:authenticate, authenticate_action(mobile, code, subscription_code_for_existing_business) ) do
        post '/api/subscriptions', params: { mobile: mobile, code: code, name: person_name, business_name: business_name, transaction_identifier: transaction_identifier, product_identifier: product_identifier }, as: :json
      end
      json_response = JSON.parse( response.body )
      response_token = json_response['token']

      token_payload = ApiRequest::JsonToken.decode( response_token )
      tokenized_person = Person.where( id: token_payload['person_id'] ).first
      assert_equal existing_person, tokenized_person

      response_business = Business.where( id: json_response['business_id'] ).first
      assert response_business
      assert_equal existing_business, response_business
    end

    def assert_business_exists(response_business_id, with_name: nil)
      response_business = Business.where( id: response_business_id ).first
      assert response_business
      if with_name
        assert_equal with_name, response_business.name
      end
    end

    test 'linking an invalid code while creating a new subscription for a user' do
      AuthenticateSubscriptionCode.stub(:authenticate, authenticate_action(mobile, 'invalid-code', stored_subscription_code) ) do
        post '/api/subscriptions', params: { mobile: mobile, code: code, name: name, business_name: business_name, transaction_identifier: transaction_identifier, product_identifier: product_identifier }, as: :json
      end

      assert_match /4\d\d/, response.code.to_s

      json_response = JSON.parse( response.body )
      assert json_response.dig('error')
      assert !json_response.dig('token')
      assert !json_response.dig('id')
    end
  end
end
