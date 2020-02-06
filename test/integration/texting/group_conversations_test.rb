require 'test_helper'

class GroupConversationsTest < ActiveSupport::TestCase
  include Texting::IntegrationTestHelper

  def around(&test)
    super do
      UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
        test.call
      end
    end
  end


  test 'add users to a group and use that to create a chat' do
    employees[:manager].texts "#add the chef, first cook and second cook to kitchen staff",
      to: root_channel
    assert_text 'added', 'chef', 'first cook', 'second cook', received_by: [employees[:manager]]

    employees[:manager].texts "#chat kitchen staff : Who is working the special event tomorrow?",
      to: root_channel

    assert_text '🆕',/Who is working the special event tomorrow/,
      received_by: employees.values_at(:cook1, :cook2, :chef),
      not_sender: employees[:manager]
  end

  test 'add users to a group and then remove them' do
    employees[:manager].texts "#add the chef, first cook, first server, second server and second cook to kitchen staff",
      to: root_channel

    assert_text 'added', 'chef', 'first cook', 'first server', 'second server', 'second cook',
      received_by: [employees[:manager]]

    employees[:manager].texts "#chat kitchen staff : Is this thing on???",
      to: root_channel

    assert_text '🆕',/[\s\S]*\nIs this thing on?/,
      received_by: employees.values_at(:cook1, :cook2, :chef, :server1, :server2),
      not_sender: employees[:manager]

    employees[:manager].texts "#remove first server and second server from kitchen staff",
      to: root_channel

    assert_text 'removed', 'first server', 'second server', 'kitchen staff', 'group',
      received_by: [ employees[:manager] ]

    employees[:manager].texts "#chat kitchen staff : How about now...",
      to: root_channel

    assert_text '🆕', /[\s\S]*\nHow about now\.\.\./,
      received_by: employees.values_at(:cook1, :cook2, :chef),
      not_sender: employees[:manager],
      and_not: employees.values_at(:server1, :server2)

    chat_channel = chat_channel_for(text_messages.last)

    employees[:cook1].texts "Yeah, that seems right...",
      to: chat_channel

    assert_text "Yeah, that seems right...",
      received_by: employees.values_at(:manager, :cook2, :chef),
      not_sender: employees[:cook1]
  end

  test 'list groups that are available for texting' do
    employees[:manager].texts "#add the chef, first cook, first server, second server and second cook to kitchen staff, all staff and friends",
      to: root_channel

    employees[:chef].texts "#list all groups",
      to: root_channel

    assert_text 'Kitchen Staff', 'All Staff', 'Friends',
      received_by: [employees[:chef]],
      and_not: employees.except(:chef).values
  end
end
