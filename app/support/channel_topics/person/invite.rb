module ChannelTopics
  module Person
    class Invite < ChannelTopics::Processor
      attr_reader :service_invitation
      include ::ChannelTopics::ContactInfoHelper

      class << self
        def invite_link(channel_number, invite_code, separator: '?', skip_encode: /[^\w@\.\-!:]/ )
          # Other brackets ⟬⟭  ⟦⟧ ｢｣

          host = Rails.application.config.x.short_host
          populated_text = <<~EOT.strip
            Please join our texting group.

            sms:#{channel_number.to_s(:url)}?body=#{Addressable::URI.encode_component("⟬Add name after the ＠⟭\n\n#{invite_code}\n@ ", skip_encode)}

            or

            #{host}/s/a/#{invite_code}

            Click the link and add your name after the @
          EOT

          [ "sms:-", separator, 'body=', Addressable::URI.encode_component( populated_text, skip_encode) ].join( '' )
        end
      end

      def call
        TextMessage.transaction do
          @service_invitation = find_or_create_service_invitation

          invite_instructions.save!
          # forwardable_invite.save!
        end
      end

      def parsed_groups
        @parsed_groups ||= if group_names = contact_info_from_text[:group_names]
          TextGroup.where( name: group_names, business: channel.business )
        else
          []
        end
      end

      def find_or_create_service_invitation
        new_invite = ServiceInvitation.new( fufillment_type: 'sms', service_location: channel, code: invite_code, service_groups_to_add: parsed_groups, inviting_person: message_sender )

        ServiceInvitation.where(
          fufillment_type: new_invite.fufillment_type,
          service_location: new_invite.service_location,
          service_groups: new_invite.service_groups
        ).where(
          ServiceInvitation.arel_table[:code].not_eq(nil)
        ).where(
          ServiceInvitation.arel_table[:expires_at].gt(Time.zone.now + 2.weeks)
        ).first || new_invite.tap(&:save!)
      end

      def invite_code
        random_string = 6.times.map{ 97 + SecureRandom.random_number(26) }.pack('U*')
        [
          '!inv',
          channel_business.display_name.downcase.gsub("\s",'').first(6),
          random_string
        ].join('-')
      end

      def invite_link

        self.class.invite_link( message_to.first, service_invitation.code )
      end

      def invite_instructions
        @invite_instructions ||= text_message_out to: :sender, message_keys: instructions_text
        # TextMessage.out(
        #   message_text: instructions_text, channel: channel,
        #   original_from: message_from, to: message_from
        # )
      end

      def forwardable_invite
        @forwardable_invite ||= TextMessage.out(
          message_generator_keys: t(
            'forwardable_invite', code: service_invitation.code, business_name: channel_business.display_name,
            app_phone_number: accept_phone_number.to_s(:standard),
            app_phone_number_for_url: accept_phone_number.to_s(:url)
          ),
          channel: channel, original_from: message_from, to: message_from,
          send_in: 10.seconds
        )
      end

      class << self
        def forwardable_invite_text(code, business_name, app_phone_number)
          t('forwardable_invite', code: code, business_name: business_name, app_phone_number: app_phone_number, )
        end
      end

      def accept_phone_number
        message_to.first
      end

      def instructions_text
        t('instructions.main', code_expiration: service_invitation.expires_at.strftime('%a, %b %-d'), code: service_invitation.code, phone_number: accept_phone_number.to_s(:standard), groups: parsed_groups.map(&:name), invite_link: invite_link )
      end
    end
  end
end
