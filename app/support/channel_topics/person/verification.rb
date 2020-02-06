module ChannelTopics
  module Person
    class Verification < ChannelTopics::Processor

      def call
        ::Person.transaction do
          if message_verified?
            reassign_channel
            add_to_invited_text_groups
            welcome_message.save!
            accept_notification_message.save! if invitation.present?
          else
            reject_notification_message.save! if invitation.present?

          end
        end
      end

      def add_to_invited_text_groups
        if invitation.present?
          if groups = invitation.service_groups_to_add
            assign_person_to_groups(message_sender, groups)
          end
        end
      end

      def invitation
        @invitation ||= message_sender.service_invitations.where( service_location: channel ).last
      end

      def assign_person_to_groups(person, groups)
        groups.each{|group| group.people << person }

        new_join_records = groups.inject([]){|acc,group|
          acc + group.text_group_people.find_all{|tgp| tgp.previous_changes[:id].present? && tgp.previous_changes.dig(:dig,0).nil? }
        }

        new_join_records.each(&:add_person_to_group_chats)
      end

      def reassign_channel
        join_record = channel.channel_people.where( person_id: message_sender.id ).first
        application_phone_number = join_record.application_phone_number
        new_join_record = message_sender.channel_people.build( channel: root_channel, application_phone_number: application_phone_number )

        join_record.destroy!
        new_join_record.save!
      end

      def welcome_message
        @welcome_message ||= text_message_out to: :sender, message_keys: welcome_message_text, channel: root_channel, media: welcome_message_media
      end

      def welcome_message_media
        [ Rails.application.routes.url_helpers.app_contact_card_with_name_url( host: Rails.application.config.x.short_host, protocol: 'http', only_path: false, business_id: channel_business.id, person_id: message_sender.id, filename: Addressable::URI.encode("#{channel_business.display_name} Texting"), format: :vcf, skip: :ssl ) ]
      end

      def welcome_message_text
        t('welcome', business_name: channel_business.display_name, person_name: message_sender.display_name, permanent_rooms: permanent_rooms_list, important_contacts: important_contacts_list )
      end

      def message_verified?
        !message_text.match(/(?:^|\s)[Nn][Oo](?:$|\s)/)
      end

      def important_contacts
        [
          invitation.try(:inviting_person),
          channel_business.text_groups.left_joins(:channels).where(channels: {id: nil}).first(4)
        ].flatten.compact
      end

      def important_contacts_list
        important_contacts.map do |c|
          mention_code = if c.respond_to?(:mention_code)
            c.mention_code( within: root_channel )
          else
            c.display_name
          end

          [c.display_name, mention_code ]
        end
      end

      def accept_notification_message
        @accept_notification_message ||= text_message_out to: invitation.inviting_person_mobile, channel: root_channel, message_keys: t('inviter.accept', business_name: channel_business.display_name, person_name: message_sender.display_name, mention_code: message_sender.mention_code( within: root_channel))
      end

      def reject_notification_message
        @reject_notification_message ||= text_message_out to: invitation.inviting_person_mobile, channel: root_channel, message_keys: t('inviter.reject', business_name: channel_business.display_name, person_name: message_sender.display_name)
      end

      def permanent_rooms
        ChannelPerson.where( person_id: message_sender.id ).joins(channel: :text_groups).preload(:application_phone_number).where( channels: {topic: ::Channel::ROOM_TOPIC} )
      end

      def permanent_rooms_list
        permanent_rooms.map do |channel_person|
          [ channel_person.channel.text_groups.map(&:name).to_sentence, channel_person.channel_phone_number.to_s(:url) ]
        end
      end

    end
  end
end
