require 'test_helper'

class UserErrorsTest < ActiveSupport::TestCase
  include Texting::IntegrationTestHelper

  test 'an existing user tries to do something unknown' do
    employees[:manager].texts '#blergh grits', to: root_channel

    assert_text "We're not sure what to do with your last message.", received_by: [employees[:manager]]
  end

  test 'an unknown user tries to do something unknown' do
    unregistered_user = PersonTextTestWrapper.new( Person.new( mobile: '14445556789' ), self)
    app_phone_number = ApplicationPhoneNumber.first.number
    unregistered_user.texts "v-2343343\n@ Mr Magoo", to: app_phone_number

    assert_text "Are you trying to register?", received_by: [unregistered_user]
  end

  test 'a user tries to chat with people that are indecipherable' do
    employees[:manager].texts '#chat with @whoisits @whatsis : This is a message', to: root_channel
    assert_text "We're having trouble figuring out who you're trying to chat with.", received_by: [employees[:manager]]
  end

  test 'a user fails to add a person to a group' do
    employees[:manager].texts '#add no one to  ', to: root_channel
    assert_text "couldn't", '#list', received_by: [ employees[:manager] ]

    employees[:manager].texts "#add #{employees[:server1].name} to  ", to: root_channel
    assert_text "couldn't", employees[:server1].name, received_by: [ employees[:manager] ]

    employees[:manager].texts "#add no one to some group ", to: root_channel
    assert_text "couldn't", '#list', received_by: [ employees[:manager] ]
  end

  test 'a user fails to remove a person to a group' do
    employees[:manager].texts '#remove no one from  ', to: root_channel
    assert_text "couldn't", '#list', received_by: [ employees[:manager] ]
    employees[:manager].texts "#remove #{employees[:server1].name} from  ", to: root_channel

    assert_text "couldn't", employees[:server1].name, received_by: [ employees[:manager] ]

    employees[:manager].texts "#remove no one from some group ", to: root_channel
    assert_text "couldn't", '#list', received_by: [ employees[:manager] ]
  end

  test 'a user fails to add a person to a chat' do

    employees[:manager].texts "#chat #{employees[:server1].name}, #{employees[:server2].name}: Hey, can you two switch shifts tomorrow?",
      to: root_channel
    chat_channel = chat_channel_for(text_messages[0])

    employees[:manager].texts '#add no one', to: chat_channel
    assert_text "couldn't", '#list', received_by: [ employees[:manager] ]
  end

  test 'a user fails to remove a person to a chat' do
    employees[:manager].texts "#chat #{employees[:server1].name}, #{employees[:server2].name}: Hey, can you two switch shifts tomorrow?",
      to: root_channel
    chat_channel = chat_channel_for(text_messages[0])

    employees[:manager].texts '#remove no one', to: chat_channel
    assert_text "couldn't", 'remove', '#list', received_by: [ employees[:manager] ]
  end
end
