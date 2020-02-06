require 'test_helper'

module TextChannelWorker
  class AddPersonFromGroupChatsTest < ActiveSupport::TestCase

    def people
      @people ||= [ Person.create!(name: 'John'), Person.create!( name: 'Joan' ) ]
    end

    def text_group
      @text_group ||= TextGroup.create!( name: 'A text group', people: people, channels: [channel], business: business )
    end

    def business
      @business ||= Business.create!( name: "A business" )
    end

    def channel
      @channel ||= Channel.create! topic: ::Channel::CHAT_TOPIC, business: business
    end


    test 'Adds people in channel group to the channel' do
      worker = TextChannelWorker::AddPersonToGroupChats.new
      person = people.first

      text_group_person = text_group.text_group_people.find{|tgp| tgp.person_id == person.id}

      worker.perform( text_group_person.id )

      assert person.channel_people.present?
      assert text_group.id, person.channel_people.first.added_from_text_group_id
    end

    test 'Will not create multiple join records' do
      person = people.first
      channel.people << person

      text_group_person = text_group.text_group_people.find{|tgp| tgp.person_id == person.id}


      worker = TextChannelWorker::AddPersonToGroupChats.new
      worker.perform( text_group_person.id )

      assert_equal 1, ChannelPerson.where( person: people.first, channel: channel ).count
    end
  end
end
