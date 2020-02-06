class ChannelGroup < ApplicationRecord
  belongs_to :channel
  belongs_to :text_group

  after_commit :add_group_users_to_channel, on: :create
  after_commit :remove_group_users_from_channel, on: :destroy

  def remove_group_users_from_channel
    TextChannelWorker::RemoveFromGroup.perform_async( self.id, self.channel_id, self.text_group_id )
  end

  def add_group_users_to_channel
    TextChannelWorker::AddFromGroup.perform_async( self.id )
  end
end
