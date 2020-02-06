module TextChannelWorker
  class RemovePersonFromGroupChats
    include Sidekiq::Worker

    def perform( text_group_person_id, person_id, text_group_id )
      if TextGroupPerson.where( id: text_group_person_id ).exists?
        raise ArgumentError, "#TextGroupPerson with id=#{text_group_person_id} hasn't been deleted."
      end

      remove_person_from_group_chats(person_id, text_group_id)
    end

    def remove_person_from_group_chats(person_id, text_group_id)
      ChannelPerson.where( person_id: person_id, added_from_text_group_id: text_group_id ).delete_all
    end
  end
end
