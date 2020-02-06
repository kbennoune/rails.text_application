module ChannelTopics
  module Person
    class Accept < ChannelTopics::Processor
      attr_reader :person, :invitation

      include UnicodeFormatting::Helper

      def call
        if (@invitation = get_service_invitation).present?
          if name = get_name
            ::Person.transaction do
              phone_number = message_from
              @person = ::Person.create!( name: name, mobile: phone_number )

              person.channels << invitation.service_location

              if groups = invitation.service_groups_to_add
                groups.each{|group| group.people << person }

                new_join_records = groups.inject([]){|acc,group|
                  acc + group.text_group_people.find_all{|tgp| tgp.previous_changes[:id].present? && tgp.previous_changes.dig(:dig,0).nil? }
                }

                new_join_records.each(&:add_person_to_group_chats)
              end

              welcome_message.save

              if invitation.inviting_person.present?
                notification_message.save
              end
            end
          else
            name_clarification_message.save!
          end
        else
          invite_code_clarification_message.save!
        end
      end

      def welcome_message
        text_message_out to: :sender, message_keys: welcome_message_text, channel: root_channel, media: welcome_message_media
      end

      def notification_message
        text_message_out to: invitation.inviting_person_mobile, channel: root_channel, message_keys: t('success.inviter', business_name: business.display_name, person_name: person.display_name, mention_code: person.mention_code( within: root_channel) )
      end

      def root_channel
        invitation.service_location
      end

      def welcome_message_media
        [ Rails.application.routes.url_helpers.app_contact_card_with_name_url( host: Rails.application.config.x.short_host, protocol: 'http', only_path: false, business_id: business.id, person_id: person.id, filename: Addressable::URI.encode("#{business.display_name} Texting"), format: :vcf, skip: :ssl ) ]
      end

      def business
        root_channel.business
      end

      def important_contacts
        [ invitation.inviting_person, business.text_groups.left_joins(:channels).where(channels: {id: nil}).first(4) ].flatten.compact
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

      def permanent_rooms
        ChannelPerson.where( person_id: person.id ).joins(channel: :text_groups).preload(:application_phone_number).where( channels: {topic: ::Channel::ROOM_TOPIC} )
      end

      def permanent_rooms_list
        permanent_rooms.map do |channel_person|
          [ channel_person.channel.text_groups.map(&:name).to_sentence, channel_person.channel_phone_number.to_s(:url) ]
        end
      end

      def welcome_message_text
        t('welcome', business_name: business.display_name, person_name: person.display_name, permanent_rooms: permanent_rooms_list, important_contacts: important_contacts_list )
      end

      def name_clarification_message
        text_message_out to: :sender, message_keys: name_clarification_message_text
      end

      def invite_code_clarification_message
        text_message_out to: :sender, message_keys: invite_code_clarification_message_text
      end

      def name_clarification_message_text
        t('clarification.name', phone_number: message_to.first.formatted, code: ChannelTopics::Person::Invite.forwardable_invite_text('!inv-code-here', channel_business.display_name, message_to.first.formatted))
      end

      def invite_code_clarification_message_text
        t('clarification.code', phone_number: message_to.first.formatted, code: ChannelTopics::Person::Invite.forwardable_invite_text('!inv-code-here', channel_business.display_name, message_to.first.formatted) )
      end

      def get_name
        if line = find_name_line
          line.gsub('@','').strip
        end
      end

      def find_name_line
        message_text.lines.reverse.find{|line|
          line.match(/(\w+\s*@|\s*\w+)/) && !line.match('an @')
        }
      end

      def get_service_invitation
        if code = message_text.scan(/!inv-[a-z]{4,10}-[a-z]{4,10}/).first
          ServiceInvitation.where( code: code, fufillment_type: 'sms' ).first
        end
      end
    end
  end
end
