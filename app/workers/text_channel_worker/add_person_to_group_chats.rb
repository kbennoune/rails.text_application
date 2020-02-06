module TextChannelWorker
  class AddPersonToGroupChats
    include Sidekiq::Worker

    attr_reader :join_record
    delegate :person, :text_group, to: :join_record, prefix: nil

    def perform( text_group_person_id )
      @join_record = TextGroupPerson.find( text_group_person_id )

      add_person_to_group_chats
    end

    def add_person_to_group_chats
      TextGroupPerson.transaction do
        ::ChannelPerson.create_with( added_from_text_group: text_group  ).scoping do
          text_group.channels.each do |channel|
            channel.people.unique_push person
          end
        end
      end
    end
  end
end
