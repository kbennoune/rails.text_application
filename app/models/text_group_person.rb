class TextGroupPerson < ApplicationRecord
  belongs_to :person
  belongs_to :text_group

  delegate :name, to: :text_group, prefix: true

  after_commit :async_add_person_to_group_chats, on: :create
  after_commit :async_remove_person_from_group_chats, on: :destroy

  attr_accessor :sync_callbacks

  def async_add_person_to_group_chats
    TextChannelWorker::AddPersonToGroupChats.perform_async( self.id )
  end

  def async_remove_person_from_group_chats
    TextChannelWorker::RemovePersonFromGroupChats.perform_async( self.id, person_id, text_group_id )
  end

  def add_person_to_group_chats
    TextChannelWorker::AddPersonToGroupChats.new.perform( self.id )
  end

  def remove_person_from_group_chats
    TextChannelWorker::RemovePersonFromGroupChats.new.perform( self.id, person_id, text_group_id )
  end
end
