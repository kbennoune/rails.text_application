class TextMessageHistory < Array
  def initialize
    super([])
  end

  def push_messages(params)
    push( *params.map{|p|
      puts "\nSending:\n".indent(2)
      puts p[:text].to_s
      puts "\n"
      { sent: Time.now, message: p  }
    } )
  end

  def received_text?(phone_number, msgs)
    find_all{|tm|
      phone_number === tm[:message][:to] &&
      msgs.all?{|msg|
        normalized(tm[:message][:text])[ msg ] }
      }.present?
  end

  def normalized(string)
    ActiveSupport::Multibyte::Chars.new(string).normalize.to_s
  end
end

class PersonTextTestWrapper < SimpleDelegator
  attr_reader :text_messages, :tests

  def is_a?(klass)
    if klass == Person
      true
    else
      super
    end
  end

  class << self
    def primary_key
      Person.primary_key
    end
  end

  def initialize(person, tests)
    @text_messages = tests.text_messages
    @tests = tests
    super(person)
  end

  def app_number(channel)
    channel.channel_people.find{|cp| cp.person_id == self.id }.channel_phone_number
  end

  def received_text?(msgs)
    text_messages.received_text?(mobile, msgs)
  end

  def recieved_text_messages
    text_messages.find_all{|tm| tm[:message][:to] == phone_number }
  end

  def texts2(to:, msg:)
    texts(msg, to: to)
  end

  def texts(msg, to:, with_attachments: [], time: Time.now)
    to_phone = get_app_number(to)
    message_id = random_message_id
    user_id = Rails.application.secrets.bandwidth[:user_id]
    message_uri = "https://api.catapult.inetwork.com/v1/users/#{user_id}/messages/#{message_id}"
    files = with_attachments

    params = {
      eventType: files.present? ? 'mms' : 'sms',
      time: time.utc.strftime('%FT%TZ'),
      direction: 'in', applicationId: '@ppl1cationId',
      state: 'recieved', messageId: message_id,
      media: files, messageUri: message_uri,
      to: "+#{to_phone}", text: msg, from: "+#{mobile}"
    }

    request = request_mock( params: params )

    text_sent_to_controller( params, request )
    run_all_sidekiq_workers
  end

  def run_all_sidekiq_workers
    until (runs ||= 0) > 10 && Sidekiq::Worker.jobs.blank?
      Sidekiq::Worker.jobs.map{|j| j['class'] }.uniq.each{|worker| worker.constantize.drain }
      runs += 1
    end
  end

  def text_sent_to_controller(params, request)
    controller = BandwidthEndpoints::MmsController.new
    controller.params = params
    controller.response = OpenStruct.new request: request
    controller.request = request
    controller.send :create
  end

  def get_app_number(channel_or_number)
    if channel_or_number.kind_of?(::Channel)
      channel_or_number.channel_people.find{|cp| cp.person_id == self.id || cp.person.real_people.map(&:id).include?(self.id) }.channel_phone_number
    else
      channel_or_number
    end
  end

  def random_message_id
    "m-#{SecureRandom.uuid.gsub('-','').last(24)}"
  end

  def request_mock(params)
    mock = Minitest::Mock.new
    def mock.headers; {}; end
    def mock.body; OpenStruct.new( read: '' ); end
    mock
  end

  private
    def to_ary(*args)
      __getobj__.send(:to_ary, *args)
    end
end

module Texting
  module IntegrationTestHelper
    attr_accessor :text_messages

    def around(&test)
      @text_messages = TextMessageHistory.new
      Sidekiq::Testing.fake! do
        Bandwidth::Message.stub(:create, ->(_,params){ text_messages.push_messages(params) }) do
          test.call
        end
      end
    end

    def business
      @business ||= Business.create! facebook_place: FacebookPlace.new
    end

    def root_channel
      @root_channel ||= ::Channel.create! business: business, topic: ::Channel::ROOT_TOPIC
    end

    def employees
      @employees ||= begin
        channels = [ root_channel ]
        {
          manager: ::Person.create!( mobile: '12123334440', name: 'mr manager', channels: channels ),
          server1: ::Person.create!( mobile: '12123334441', name: 'first server', channels: channels ),
          server2: ::Person.create!( mobile: '12123334442', name: 'second server', channels: channels ),
          chef: ::Person.create!( mobile: '12123334443', name: 'the chef', channels: channels ),
          cook1: ::Person.create!( mobile: '12123334444', name: 'first cook', channels: channels ),
          cook2: ::Person.create!( mobile: '12123334445', name: 'second cook', channels: channels )
        }.map{|k, p| [k, PersonTextTestWrapper.new(p, self)] }.to_h
      end
    end

    def chat_channel_for(text_message)
      TextMessageWorker::SetChannel.new.tap{|w|
        w.instance_variable_set(:@text_message, TextMessage.new( to: text_message[:message][:from], message_from: text_message[:message][:to] ))
      }.best_channel_fit

    end

    def assert_text(*texts, received_by: , not_sender: nil, and_not: [])
      received_by.each do |recipient|
        assert wrapped_person(recipient).received_text?(texts), "#{recipient.inspect} should receive the texts: \"#{texts.join('|')}\""
      end

      and_not.each do |nonrecipient|
        assert !wrapped_person(nonrecipient).received_text?(texts), "#{nonrecipient.inspect} shouldn't receive the texts: \"#{texts.join('|')}\""
      end

      if not_sender.present?
        assert !wrapped_person(not_sender).received_text?(texts), "#{not_sender.inspect} shouldn't receive the texts: \"#{texts.join('|')}\""
      end
    end

    def wrapped_person(val, wrapper: PersonTextTestWrapper)
      case
      when val.respond_to?(:received_text?) then val
      when val.kind_of?(Person) then wrapper.new(val, self)
      else
        wrapper.new( Person.new(mobile: val), self )
      end
    end
  end
end
