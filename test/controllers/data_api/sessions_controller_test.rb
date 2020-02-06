require 'test_helper'
require 'controllers/data_api/controller_test_helper.rb'

module DataApi
  class SessionsControllerTest < ActionDispatch::IntegrationTest

    def person
      @person ||= Person.create!( mobile: Faker::PhoneNumber.cell_phone, name: Faker::Name.name ).tap do |person|
        root_channel.started_by_person = person
        root_channel.people << person
        root_channel.save!
        business.admins << person
      end
    end

    def root_channel
      @root_channel ||= ::Channel.create! topic: ::Channel::ROOT_TOPIC, business: business
    end

    def business
      @business ||= Business.create!
    end

    test 'creating a new session' do
      code = '$ekret'
      AuthenticationCode.stub(:authenticate, ->(phone_number, code){ person  }) do
        post '/api/sessions', params: { mobile: person.mobile, code: code }, as: :json
      end

      json_response = JSON.parse( response.body )
      response_token = json_response['token']
      response_business_id = json_response['business_id']

      assert_equal business.id, response_business_id

      token_payload = ApiRequest::JsonToken.decode( response_token )
      assert_equal person.id, token_payload['person_id']
    end

    test 'failed creating a new session' do
      code = 'wr0ng'
      AuthenticationCode.stub(:authenticate, ->(phone_number, code){ nil }) do
        post '/api/sessions', params: { mobile: person.mobile, code: code }, as: :json
      end

      json_response = JSON.parse( response.body )
      assert_equal 401, response.status
      assert !json_response.has_key?('token')
    end
  end
end
