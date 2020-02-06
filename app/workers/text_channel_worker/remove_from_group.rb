module TextChannelWorker
  class RemoveFromGroup
    include Sidekiq::Worker

    def perform( channel_group_id, channel_id, text_group_id )
      if ChannelGroup.where( id: channel_group_id ).exists?
        raise ArgumentError, "#ChannelGroup with id=#{channel_group_id} hasn't been deleted."
      end

      remove_group_people_from_channel( channel_id, text_group_id )
    end

    def remove_group_people_from_channel( channel_id, text_group_id )
      ChannelPerson.where( channel_id: channel_id, added_from_text_group_id: text_group_id ).delete_all
    end
  end
end
