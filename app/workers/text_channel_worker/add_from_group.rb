module TextChannelWorker
  class AddFromGroup
    include Sidekiq::Worker
    attr_reader :channel_group
    delegate :channel, :text_group, to: :channel_group, prefix: false

    def perform( channel_group_id )
      @channel_group = ChannelGroup.find channel_group_id

      add_group_people_to_channel
    end

    def add_group_people_to_channel
      ::ChannelPerson.create_with( added_from_text_group: text_group  ).scoping do
        channel.people.unique_push text_group.people
      end
    end
  end
end
