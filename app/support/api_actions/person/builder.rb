module ApiActions
  module Person
    class Builder
      attr_reader :groups_to_remove, :business, :people_params, :existing_people, :groups_to_add, :invite_channel
      delegate :to_a, :map, :each, :find, to: :people

      def initialize( business, people_params, existing_people: [], groups_to_add: [], groups_to_remove: [], invite_channel: nil )
        @business = business
        @people_params = people_params
        @existing_people = existing_people
        @groups_to_add = groups_to_add
        @invite_channel = invite_channel
        @groups_to_remove = groups_to_remove
      end

      def people_root_channel_map
        @people_root_channel_map ||= if existing_people.present?
          ChannelPerson.joins(:channel).where(
            person_id: existing_people.map(&:id), channels: { topic: ::Channel::ROOT_TOPIC, business_id: business.id }
          ).map{|record|
            [ record.person_id, record.channel_id ]
          }.to_h
        else
          {}
        end
      end


      def existing_people_hash
        @existing_people_hash ||= existing_people.map{|person| [ person.mobile, person ]}.to_h
      end

      def person_already_part_of_business?( person )
        if person.id
          people_root_channel_map[ person.id ].present?
        end
      end

      def invite( person )
        person.channel_people.build channel: invite_channel
        person.service_invitations.build inviting_person: invite_channel.started_by_person, service_location: invite_channel, service_groups_to_add: groups_to_add.each(&:save!)
      end

      def person_for(hsh)
        person = if hsh.has_key?(:id)
          ::Person.find( hsh[:id] )
        elsif hsh.has_key?(:mobile)
          ::Person.where( mobile: PhoneNumber.new(hsh[:mobile]) ).first || ::Person.new( mobile: hsh[:mobile] )
        else
          ::Person.new
        end

        if person.new_record? || person_already_part_of_business?(person)
          person.attributes = hsh.with_indifferent_access.slice( *::Person.attribute_names ).except(:id)
        end

        person
      end

      def invite_person?(person)
        !person_already_part_of_business?( person ) && invite_channel.present?
      end

      def people
        @people ||= begin
          people_params.map do |hsh|
            person = person_for(hsh)

            if invite_person?(person)
              invite( person )
            else
              updated_text_groups = person.text_groups + groups_to_add - groups_to_remove

              person.text_groups = updated_text_groups
            end

            person
          end
        end
      end
    end

  end
end
