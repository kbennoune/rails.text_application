require 'test_helper'

module TextChannelWorker
  class AddFromGroupTest < ActiveSupport::TestCase

    def people
      @people ||= [ Person.create!(name: 'John'), Person.create!( name: 'Joan' ) ]
    end

    def text_group
      @text_group ||= TextGroup.new( name: 'A text group', people: people, business: Business.create!( name: "A business" ) )
    end

    def channel
      @channel ||= Channel.create! topic: ::Channel::CHAT_TOPIC, business: text_group.business
    end


    test 'Adds people in channel group to the channel' do
      channel_group = ChannelGroup.create! channel: channel, text_group: text_group

      worker = TextChannelWorker::AddFromGroup.new

      worker.perform( channel_group.id )

      people.each do |person|
        assert person.channel_people.present?
        assert text_group.id, person.channel_people.first.added_from_text_group_id
      end
    end

    test 'Will not create multiple join records' do
      channel_group = ChannelGroup.create! channel: channel, text_group: text_group

      ChannelPerson.create! person: people.first, channel: channel

      worker = TextChannelWorker::AddFromGroup.new

      worker.perform( channel_group.id )

      assert_equal 1, ChannelPerson.where( person: people.first, channel: channel ).count
    end
  end
end
