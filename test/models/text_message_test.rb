require 'test_helper'

class TextMessageTest < ActiveSupport::TestCase
  test "a phone number can be used as the message to" do
    text_message = TextMessage.new to: PhoneNumber.new('(555) 234-5678')
    assert_equal [PhoneNumber.new('5552345678')], text_message.to
  end

  test "a phone number can be used as the message from" do
    text_message = TextMessage.new message_from: PhoneNumber.new('(555) 234-5678')
    assert_equal PhoneNumber.new('5552345678'), text_message.message_from
  end

  test 'includes and preload work' do
    person = Person.create name: 'This is a user', mobile: '+5625999110'
    text_message = TextMessage.create! message_from: '+5625999110'

    msg_with_includes = TextMessage.where( id: text_message.id ).includes(:sender)
    assert_equal text_message.id, msg_with_includes.first.id
  end

  test 'serializing phone numbers into :to field uses an array' do
    phone_number = PhoneNumber.new('+1234445566')
    phone_number_2 = PhoneNumber.new('+1234445567')

    assert_equal [phone_number], TextMessage.new(to: phone_number).to
    assert_equal [phone_number], TextMessage.new(to: phone_number.digits).to

    assert_equal [phone_number, phone_number_2], TextMessage.new(to: [phone_number, phone_number_2]).to
    assert_equal [phone_number, phone_number_2], TextMessage.new(to: [phone_number.digits, phone_number_2]).to

  end

  test 'handling nil phone numbers' do
    person = Person.create! name: 'Anull Phone', mobile: nil

    text_message = TextMessage.create! original_message_from: nil, message_from: nil
    assert_nil text_message.sender
    assert_nil text_message.original_sender
  end

  test 'setting remote sent time and remote sending time' do
    time_string = "2018-05-11T17:19:45Z"

    text_message = TextMessage.new remote_sending_time: time_string, remote_sent_time: time_string

    assert_equal Time.parse(time_string), text_message.remote_sending_time
    assert_equal Time.parse(time_string), text_message.remote_sent_time

  end

  test 'serializing remote events hashes' do
    response = {:direction=>"out", :from=>"+19198642788", :id=>"m-sa4ja7gxwayjsdgpb52h52i", :message_id=>"m-sa4ja7gxwayjsdgpb52h52i", :state=>"sending", :text=>"TEST!", :media=>[], :time=>"2018-05-11T17:19:45Z", :to=>"+15625999110", :skip_mms_carrier_validation=>true}
    text_message = TextMessage.new

    text_message.remote_events = text_message.remote_events + [response]
    text_message.remote_events = text_message.remote_events + [response]

    assert_equal [response.stringify_keys, response.stringify_keys], text_message.remote_events
  end

  test 'serializing translation generator keys' do
    translation_key = I18nLazy.new('this.is.a.key', { key1: 'a string', key2: ['a', 'r', 'r', 'a', 'y'] })
    text_message = TextMessage.new
    text_message.message_generator_keys = translation_key

    new_translation_key = I18nLazy.from_json( text_message.message_generator_keys.first )
    assert_equal translation_key, new_translation_key

    assert_equal [translation_key], text_message.message_generators
  end

  test 'it extracts the first key for a translation fot the message type' do
    translation_key = I18nLazy.new('this.is.a.key', { key1: 'a string', key2: ['a', 'r', 'r', 'a', 'y'] })
    text_message = TextMessage.new
    text_message.message_generator_keys = translation_key

    text_message.save

    assert_equal 'this.is.a.key' ,text_message.message_generator_key 
  end
end
