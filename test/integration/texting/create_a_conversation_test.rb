require 'test_helper'

class CreateAConversationTest < ActiveSupport::TestCase
  include Texting::IntegrationTestHelper

  test 'a simple conversation started through the chat' do
    employees[:manager].texts "#chat #{employees[:server1].name}, #{employees[:server2].name}: Hey, can you two switch shifts tomorrow?",
      to: root_channel

    assert text_messages[0]

    chat_channel = chat_channel_for(text_messages[0])

    assert_text(
      "#{employees.values_at(:server1, :server2).map(&:name).to_sentence(two_words_connector: ' & ', last_word_connector: ' & ')}", "#ADD",
      received_by: [employees[:manager]], not_sender: nil, and_not: employees.values - [employees[:manager]]
    )

    assert_text("#{employees[:manager].name}, #{employees[:server1].name} & #{employees[:server2].name}", "#STOP", "Hey, can you two switch shifts tomorrow?", received_by: employees.values_at(:server1, :server2), not_sender: employees[:manager] )

    employees[:server1].texts "I'm open to that if you are, second",
      to: chat_channel

    assert_text("First Server", "I'm open to that if you are, second", received_by: employees.values_at(:manager, :server2), not_sender: employees[:server1])

    employees[:server2].texts "Yeah, that's no problem: 😊",
      to: chat_channel

    assert_text("Second Server","Yeah, that's no problem: 😊", received_by: employees.values_at(:manager, :server1), not_sender: employees[:server2])

    employees[:manager].texts "Ok, thanks!",
      to: chat_channel

    assert_text("Mr Manager", "Ok, thanks!", received_by: employees.values_at(:server1, :server2), not_sender: employees[:manager])
  end

  test 'start a conversation and remove a person' do
    employees[:manager].texts(
      "#chat #{employees[:server1].name}, #{employees[:chef].name}, #{employees[:cook1].name}: Did we get everything ready for the health inspection?",
      to: root_channel
    )
    assert_text '🆕', '#STOP', 'Did we get everything ready for the health inspection?',
      received_by: employees.values_at(:server1, :chef, :cook1), not_sender: employees[:manager]

    chat_channel = chat_channel_for(text_messages[0])
    assert_text('New Thread', "#{employees.values_at(:server1, :chef, :cook1).map(&:name).to_sentence(two_words_connector: ' & ', last_word_connector: ' & ')}","Did we get everything ready for the health inspection?", received_by: [employees[:manager]], not_sender: nil, and_not: employees.values - [employees[:manager]] )

    employees[:chef].texts "Yeah but I think the wrong person is on this chat...",
      to: chat_channel

    assert_text(
      "The Chef", "Yeah but I think the wrong person is on this chat...",
      received_by: employees.values_at(:server1, :cook1, :manager), not_sender: employees[:chef]
    )

    employees[:manager].texts "#remove #{employees[:server1].name}",
      to: chat_channel

    assert_text 'removed', 'first server', received_by: [ employees[:manager] ]

    assert_text 'removed', received_by: [ employees[:server1] ]

    employees[:manager].texts "Ok, I think that's better!",
      to: chat_channel

    assert_text("Mr Manager","Ok, I think that's better!", received_by: employees.values_at(:chef, :cook1), not_sender: employees[:manager], and_not: [employees[:server1]] )

    employees[:chef].texts "#ADD #{employees[:cook2].name}",
      to: chat_channel

    assert_text 'added you', received_by: [ employees[:cook2] ]

    employees[:chef].texts "There, I added the second cook 🚀",
      to: chat_channel

    assert_text("The Chef", "There, I added the second cook 🚀", received_by: employees.values_at(:manager, :cook1, :cook2), not_sender: employees[:chef] )
  end

  test 'start a conversation and a person removes themselves' do
    employees[:manager].texts(
      "#chat #{employees[:cook1].name}, #{employees[:chef].name}, #{employees[:cook2].name}: How are things looking with the new cook?",
      to: root_channel
    )

    assert text_messages[0]

    chat_channel = chat_channel_for(text_messages[0])

    employees[:cook1].texts(
      "Cook two quit, remember?",
      to: chat_channel
    )

    assert_text "First Cook", "Cook two quit, remember?",
      received_by: employees.values_at(:cook2, :manager, :chef),
      not_sender: employees[:cook1]

    employees[:cook2].texts "#stop",
      to: chat_channel

    assert_text 'removed', received_by: [ employees[:cook2] ]

    employees[:cook1].texts(
      "I think that cook one removed themselves",
      to: chat_channel
    )

    assert_text "First Cook", "I think that cook one removed themselves",
      received_by: employees.values_at(:manager, :chef),
      not_sender: employees[:cook1],
      and_not: [employees[:cook2]]
  end

  test 'start a chat where one of the people asks for help' do
    employees[:manager].texts(
      "#chat #{employees[:cook1].name}, #{employees[:chef].name}, #{employees[:cook2].name}: Make sure to be ready for the order, tomorrow",
      to: root_channel
    )

    assert_text /#{I18n.t('channel_topics.channel.start.success.included_header_addendum')}[\s\S]*\nMake sure to be ready for the order, tomorrow/,
      received_by: employees.values_at(:cook1, :cook2, :chef),
      not_sender: employees[:manager]

    chat_channel = chat_channel_for(text_messages[0])

    employees[:chef].texts "\n#help ", to: chat_channel

    assert_text  /(#add[\s\S]*|#remove[\s\S]*|#stop[\s\S]*){3,}/,
      received_by: [ employees[:chef] ],
      and_not: employees.values_at(:manager, :cook1, :cook2)
  end

end

class RemoveFromAConversationTest < ActiveSupport::TestCase
  include Texting::IntegrationTestHelper

  test 'start a conversation and remove a person using a short name' do
    employees[:manager].texts(
      "#chat #{employees[:cook1].name}, #{employees[:chef].name}, #{employees[:cook2].name}: How are things looking with the new cook?",
      to: root_channel
    )

    assert text_messages[0]

    chat_channel = chat_channel_for(text_messages[0])

    employees[:cook1].texts(
      "Cook two quit has the day off, remember?",
      to: chat_channel
    )

    assert_text "First Cook", "Cook two quit has the day off, remember?",
      received_by: employees.values_at(:cook2, :manager, :chef),
      not_sender: employees[:cook1]

    mention_code = employees[:cook2].mention_code( within: chat_channel )

    employees[:manager].texts "#remove #{mention_code}",
      to: chat_channel

    employees[:cook1].texts(
      "Cook 1 can't see this...",
      to: chat_channel
    )

    assert_text "First Cook", "Cook 1 can't see this...",
      received_by: employees.values_at(:manager, :chef),
      not_sender: employees[:cook1],
      and_not: [employees[:cook2]]
  end
end
