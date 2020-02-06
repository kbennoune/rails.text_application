require 'test_helper'

module TextMessageWorker
  class SendTest < ActiveSupport::TestCase

    def message_text
      <<-EOM
        This is some text
        that is on multiple lines
      EOM
    end

    def message_media
      ['http://path/to/file1', 'http://path/to/file2']
    end

    def people
      [
        ::Person.new( name: 'Jaime', mobile: '5555551000'),
        ::Person.new( name: 'Terry', mobile: '5555551001'),
        ::Person.new( name: 'Jesse', mobile: '5555551002'),
        ::Person.new( name: 'Taylor', mobile: '5555551003'),
        ::Person.new( name: 'Francis', mobile: '5555551004')
      ].inject({}){|acc, p| acc[p.name] = p; acc}
    end

    def chat_channel
      @chat_channel ||= Channel.create!( topic: Channel::CHAT_TOPIC, business: Business.new ).tap do |channel|
        channel.people << people.values
      end
    end

    def text_message
      @text_message ||= TextMessage.create!(
        app_status: TextMessage::APP_STATUS_QUEUED,
        channel: chat_channel,
        message_text: message_text,
        message_media: message_media
      )
    end

    def assert_api_sends(params)
      @api_called = true
      assert_equal expected_receivers.map(&:mobile).to_set, params.map{|param| param[:to]}.to_set
      assert_empty params.find_all{|param| !param[:text].match message_text}
      assert_empty params.find_all{|param| param[:media] != message_media}
      { id: 'msg-test-id' }
    end

    def assert_api_called
      assert @api_called
    end

    def assert_not_called(*)
      assert false
    end

    test 'it will send a queued message to all users in a channel' do
      worker = TextMessageWorker::Send.new

      worker.stub(:create_text_message, method(:assert_api_sends) ) do
        worker.perform( text_message.id )
      end

      assert_api_called
      assert_equal TextMessage::APP_STATUS_SENT, worker.text_message.app_status
    end

    test "it ignores messages that aren't queued" do
      text_message.update( app_status: TextMessage::APP_STATUS_SENT)
      worker = TextMessageWorker::Send.new
      worker.stub(:create_text_message, method(:assert_not_called) ) do
        worker.perform( text_message.id )
      end
      assert_equal TextMessage::APP_STATUS_SENT, worker.text_message.app_status
    end

    def assert_create_args(client, params)
      assert_equal :fake_client, client
      assert_equal expected_receivers.size, params.size
      { id: 'this-is-an-id' }
    end

    def expected_receivers
      people.values
    end

    test 'it uses a text message translation' do
      I18n.backend.store_translations(:en, some_word: '%{what} translation')

      text_message = TextMessage.create!(
        app_status: TextMessage::APP_STATUS_QUEUED,
        channel: chat_channel,
        message_generator_keys: I18nLazy.new('some_word', what: 'fake')
      )

      worker = TextMessageWorker::Send.new

      assert_message = proc{|params|
        params.each{|param| assert_equal 'fake translation', param[:text] }
        assert_equal expected_receivers.map(&:mobile).to_set, params.map{|p| p[:to] }.to_set
        {}
      }

      recipients = []

      assert_text_generator = proc{|recipient, tm|
        recipients << recipient
        assert_equal text_message, tm
        'fake translation'
      }

      worker.stub(:create_text_message, assert_message){
        worker.stub(:message_text_for, assert_text_generator){
          worker.perform(text_message.id)
        }
      }

      assert_equal expected_receivers.map(&:mobile).to_set, recipients.map(&:person).map(&:mobile).to_set
    end

    test 'it uses a hard coded text translation' do
      I18n.backend.store_translations(:en, some_word: '%{what} translation')

      text_message = TextMessage.create!(
        app_status: TextMessage::APP_STATUS_QUEUED,
        channel: chat_channel,
        message_text: 'SUPERCEDES TRANSLATIONS!',
        message_generator_keys: I18nLazy.new('some_word', what: 'fake')
      )

      worker = TextMessageWorker::Send.new

      assert_message = proc{|params|
        params.each{|param| assert_match 'SUPERCEDES TRANSLATIONS!', param[:text] }
        assert_equal expected_receivers.map(&:mobile).to_set, params.map{|p| p[:to] }.to_set
        {}
      }

      worker.stub(:create_text_message, assert_message){ worker.perform(text_message.id) }
    end

    test "it calls create on the bandwidth api" do
      worker = TextMessageWorker::Send.new
      assert_kind_of Bandwidth::Client, worker.client

      worker.stub(:client, :fake_client ) do
        Bandwidth::Message.stub(:create, method(:assert_create_args)) do
          worker.perform( text_message.id )
        end
      end
    end
  end

  class SendToAliasesTest < SendTest

    def people
      @people ||= (real_people = super).tap do |hsh|
        hsh.values.each(&:save!)
        hsh['alias'] = Person.create! name: 'alias', active_real_people: real_people.values_at('Jesse', 'Taylor')
      end
    end

    def chat_channel
      @chat_channel ||= Channel.create!( topic: Channel::CHAT_TOPIC, business: Business.new ).tap do |channel|
        channel.people << people.values_at('Jaime', 'Terry', 'alias')
      end
    end

    def expected_receivers
      people.values_at( 'Jaime', 'Terry', 'Jesse', 'Taylor')
    end

  end
end
