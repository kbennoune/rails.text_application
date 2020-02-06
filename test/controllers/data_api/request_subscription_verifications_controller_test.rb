require 'test_helper'
require 'controllers/data_api/controller_test_helper.rb'

module DataApi
  class RequestSubscriptionVerificationsControllerTest < ActionDispatch::IntegrationTest
    include ControllerTestHelper

    def mobile
      '9193217654'
    end

    def product_identifier
      'Pr*ductId3nt1f13r'
    end

    def transaction_identifier
      'Tr@n@ctionId3nt1f13r'
    end

    def transaction_receipt
      'Tr@n@ctionR3c31pt'
    end

    def transaction_date
      'Tr@n@ct1onD@t3'
    end

    test 'requesting a code' do
      post '/api/request_subscription_verification', as: :json, params: { mobile: mobile, product_identifier: product_identifier, transaction_identifier: transaction_identifier, transaction_receipt: transaction_receipt, transaction_date: transaction_date }
      assert_equal 201, response.status
      assert_equal 1, TextMessageWorker::Send.jobs.size
      text_message_record = TextMessage.find( TextMessageWorker::Send.jobs.dig(0, 'args', 0) )

      message_keys = text_message_record.message_generator_keys[0]

      assert_match /\d{6}/, message_keys.dig('values','code')
    end

    test 'requesting a code with an existing subscription' do
      existing_subscription = Subscription.create!( product_identifier: product_identifier, transaction_identifier: transaction_identifier, transaction_receipt: transaction_receipt, transaction_date: transaction_date )

      post '/api/request_subscription_verification', as: :json, params: { mobile: mobile, product_identifier: product_identifier, transaction_identifier: transaction_identifier, transaction_receipt: transaction_receipt, transaction_date: transaction_date }
      assert_equal 201, response.status
      assert_equal 1, TextMessageWorker::Send.jobs.size
      text_message_record = TextMessage.find( TextMessageWorker::Send.jobs.dig(0, 'args', 0) )

      message_keys = text_message_record.message_generator_keys[0]
      code = message_keys.dig('values','code')

      assert_equal existing_subscription, AuthenticateSubscriptionCode.where( code: code ).first.try(:subscription)
    end

    def assert_api_sends(params)
      @api_called = true
      assert_equal expected_receivers.map(&:mobile).to_set, params.map{|param| param[:to]}.to_set
      assert_empty params.find_all{|param| !param[:text].match message_text}
      assert_empty params.find_all{|param| param[:media] != message_media}
      { id: 'msg-test-id' }
    end

    test 'requesting a code creates a usable text message' do
      post '/api/request_subscription_verification', as: :json, params: { mobile: mobile, product_identifier: product_identifier, transaction_identifier: transaction_identifier, transaction_receipt: transaction_receipt, transaction_date: transaction_date }

      text_message_job = TextMessageWorker::Send.jobs.dig(0, 'args', 0)
      text_message_record = TextMessage.find( text_message_job )
      assert text_message_record

      assert_message_sends_to mobile, text_message_record
    end

    def assert_message_sends_to(mobile, text_message_record)
      worker = TextMessageWorker::Send.new

      message_keys = text_message_record.message_generator_keys[0]
      code = message_keys.dig('values','code')

      assert_api_sends = Proc.new do |(params,_)|
        @api_called = true

        assert_match code, params[:text]
        assert_equal PhoneNumber.new(mobile), params[:to]
        assert ApplicationPhoneNumber.where( number: params[:from] ).last

        { id: 'msg-test-id' }
      end

      worker.stub(:create_text_message, assert_api_sends ) do
        worker.perform( text_message_record.id )
      end
    end
  end
end
