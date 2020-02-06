require 'test_helper'

module TextChannelWorker
  class RemoveFromGroupTest < ActiveSupport::TestCase

    def text_group
      @text_group ||= TextGroup.new( name: 'A text group', people: [ Person.create!(name: 'John'), Person.create!( name: 'Joan' ) ], business: Business.create!( name: "A business" ) )
    end

    def channel
      @channel ||= Channel.create! topic: ::Channel::CHAT_TOPIC, business: text_group.business
    end

    test 'removes all of the people who were added to a group through a channel' do
      ::ChannelPerson.create_with( added_from_text_group: text_group  ).scoping do
        channel.people.unique_push text_group.people
      end

      additional_person = Person.new(name: 'Joyce')
      channel.people.unique_push additional_person
      assert_equal 3, channel.people.count

      worker = TextChannelWorker::RemoveFromGroup.new
      worker.perform(0, channel.id, text_group.id)

      assert_equal ['Joyce'], channel.people.reload.map(&:name)
    end

    test 'it throws an error if the channel group has not been deleted' do
      channel_group = ChannelGroup.create! channel: channel, text_group: text_group

      assert_raises(ArgumentError){ TextChannelWorker::RemoveFromGroup.new.perform(channel_group.id, 0, 0) }
    end

  end
end
