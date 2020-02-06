require 'test_helper'

module TextChannelWorker
  class RemovePersonFromGroupChatsTest < ActiveSupport::TestCase

    def text_group
      @text_group ||= TextGroup.new( name: 'A text group', people: [ Person.create!(name: 'John'), Person.create!( name: 'Joan' ) ], business: Business.create!( name: "A business" ) )
    end

    def channel
      @channel ||= Channel.create! topic: ::Channel::CHAT_TOPIC, business: business
    end

    def business
      @business ||= Business.create!( name: "A business" )
    end

    test 'removes a person who was removed from a group' do
      person = text_group.people.first

      ::ChannelPerson.create_with( added_from_text_group: text_group  ).scoping do
        channel.people.unique_push person
      end

      additional_channel = Channel.create!(topic: ::Channel::CHAT_TOPIC, business: business, people: [ person ])

      worker = TextChannelWorker::RemovePersonFromGroupChats.new
      worker.perform(0, person.id, text_group.id)

      assert_equal [additional_channel], person.channels.reload
    end

    test 'it throws an error if the person group has not been deleted' do
      person = text_group.people.first
      join_record = TextGroupPerson.create! person: person, text_group: text_group

      assert_raises(ArgumentError){ TextChannelWorker::RemovePersonFromGroupChats.new.perform(join_record.id, 0, 0) }
    end

  end
end
