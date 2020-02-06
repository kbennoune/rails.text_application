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


  test 'invite people to a channel and start chatting' do
    invite_message = <<~EOS
      #invite to (everyone, front of the house): (Kai Rocha Costa 2134556789) (Tjitske Wijngaard 2131235678)
    EOS

    employees[:manager].texts invite_message, to: root_channel

    assert_text /Accept by responding YES/, /NO/,
      received_by: ['2134556789', '2131235678']

    employees[:manager].texts '@kai @tjitske @firstcook This message should go to the first cook',
      to: root_channel

    assert_text 'This message should go to the first cook',
      received_by: [employees[:cook1]],
      and_not: ['2134556789', '2131235678']

    new_people = ::Person.where( mobile: ['2134556789', '2131235678'] ).map{|p| wrapped_person(p) }

    new_people[0].texts ' yes ', to: new_people[0].channels[0]
    assert_text 'Welcome', new_people[0].channel_people[0].channel_phone_number.to_s(:url),
      received_by: [new_people[0]]

    assert_text 'Kai Rocha Costa (@kcosta) joined!',
      received_by: [employees[:manager]]

    new_people[1].texts 'no', to: new_people[1].channels[0]

    assert_text 'Tjitske Wijngaard rejected',
      received_by: [employees[:manager]]

    employees[:manager].texts '@kai @tjitske @firstcook This message should go to the first cook and kai',
      to: root_channel

    assert_text 'This message should go to the first cook and kai',
      received_by: [ employees[:cook1], new_people[0] ],
      and_not: [ new_people[1] ]
  end
end
