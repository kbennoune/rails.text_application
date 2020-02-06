require 'test_helper'
require 'controllers/data_api/controller_test_helper.rb'

module DataApi
  class RequestAuthenticationsControllerTest < ActionDispatch::IntegrationTest
    include ControllerTestHelper

    def existing_user
      @person ||= ::Person.create! name: Faker::Name.name, mobile: Faker::PhoneNumber.cell_phone, channels: [ root_channel ]
    end

    def root_channel
      @root_channel ||= Channel.create! business: Business.create!, topic: ::Channel::ROOT_TOPIC
    end

    def existing_user_without_channel
      @person ||= ::Person.create! name: Faker::Name.name, mobile: Faker::PhoneNumber.cell_phone
    end

    test 'requesting a code' do
      post '/api/request_authentication', params: { mobile: existing_user.mobile.digits }, as: :json
      assert_equal 201, response.status
      assert_equal 1, TextMessageWorker::Send.jobs.size
      text_message_record = TextMessage.find( TextMessageWorker::Send.jobs.dig(0, 'args', 0) )

      assert_equal root_channel, text_message_record.channel
      message_keys = text_message_record.message_generator_keys[0]

      assert_match /\d{6}/, message_keys.dig('values','code')
      assert_equal existing_user.mobile, text_message_record.to[0]
    end

    test 'requesting a code as a user without a topic' do
      # This is useless until the rules for administered_by change
      Business.stub(:administered_by, ->(person){ [ root_channel.business ] }) do
        post '/api/request_authentication', params: { mobile: existing_user_without_channel.mobile.digits }, as: :json
      end

      assert_equal 201, response.status
      assert_equal 1, TextMessageWorker::Send.jobs.size
      text_message_record = TextMessage.find( TextMessageWorker::Send.jobs.dig(0, 'args', 0) )

      invite_channel = text_message_record.channel
      assert invite_channel.present?
      assert_equal invite_channel.people, [ existing_user_without_channel ]

      message_keys = text_message_record.message_generator_keys[0]

      assert_match /\d{6}/, message_keys.dig('values','code')
      assert_equal existing_user.mobile, text_message_record.to[0]
    end

    test 'requesting a code without a user' do
      post '/api/request_authentication', params: { mobile: Faker::PhoneNumber.cell_phone }, as: :json
      assert_equal 402, response.status

    end

  end
end
