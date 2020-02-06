require 'test_helper'

class ConversationsWithAliasesTest < ActiveSupport::TestCase
  include Texting::IntegrationTestHelper

  test 'a user starts a conversation with the active person assigned to the alias' do
    manager_on_duty = Person.create! name: 'manager_on_duty', real_people: employees.values_at(:manager, :chef)
    manager_on_duty.channels << root_channel

    employees[:manager].texts( '#set @onduty to @manager', to: root_channel )
    employees[:manager].texts( '#set @onduty to @chef', to: root_channel )

    employees[:cook1].texts(
      "@onduty I'm going to be an hour late. My car is broken.",
      to: root_channel
    )

    assert_text "I'm going to be an hour late. My car is broken.",
      received_by: [ employees[:chef], employees[:cook1] ],
      and_not: [ employees[:manager] ]

    chat_channel = chat_channel_for(text_messages[0])

    employees[:chef].texts( "Ok, please hurry up!", to: chat_channel )

    assert_text "Ok, please hurry up!",
      received_by: [ employees[:cook1] ],
      and_not: [ employees[:manager] ]

    employees[:manager].texts( '#set @onduty to @manager', to: root_channel )

    employees[:cook1].texts("I'm almost there!!!", to: chat_channel)

    assert_text "I'm almost there!!!",
      received_by: [ employees[:manager] ],
      and_not: [ employees[:chef] ]

    employees[:chef].texts("I forgot to tell you that cook1 was going to be late...", to: chat_channel)
    assert_text "I forgot to tell you that cook1 was going to be late...",
      received_by: employees.values_at(:manager, :cook1),
      not_sender: employees[:chef]

  end

end
