module TextMessageWorker
  class Onboard
    include Sidekiq::Worker

    attr_reader :person, :business, :service_invitation, :options

    include UnicodeFormatting::Helper

    # options
    #   send_text: false will skip sending the welcome email
    def perform(person_id, business_id, options={})
      @person = Person.find(person_id)
      @business = Business.find( business_id )
      @options = options
      Channel.transaction{ save_all_records! }
    end

    def save_all_records!
      if !root_channel.channel_people.where( person_id: person.id ).exists?
        root_channel.people << person
        root_channel.save!
      end

      if @options[:send_text] != false
        onboard_text.save!
      end
    end

    def onboard_text
      @onboard_text ||= TextMessage.out(
        message_text: onboard_message_text, channel: root_channel,
        to: person.mobile, media: onboard_message_media
      )
    end

    def onboard_message_media
      # Currently bandwidth doesn't work with let's encrypt
      # so we have to use http instead of https
      # When they upgrade their JAVA we might be able to turn it
      # back to Rails.application.config.x.short_host_protocol
      [ Rails.application.routes.url_helpers.app_contact_card_url( host: Rails.application.config.x.short_host, protocol: 'http', only_path: false, business_id: business.id, person_id: person.id, format: :vcf, skip: :ssl ) ]
    end

    def onboard_message_text
      [welcome_text].join("\n")
    end

    def find_or_create_service_invitation
      new_invite = ServiceInvitation.new( fufillment_type: 'sms', service_location: root_channel, code: invite_code, service_groups_to_add: [], inviting_person: person )

      ServiceInvitation.where(
        fufillment_type: new_invite.fufillment_type,
        service_location: new_invite.service_location,
        service_groups: new_invite.service_groups
      ).where(
        ServiceInvitation.arel_table[:expires_at].gt(Time.zone.now + 1.month)
      ).first || new_invite.tap(&:save!)
    end

    def invite_code
      random_string = 6.times.map{ 97 + SecureRandom.random_number(26) }.pack('U*')
      [
        '!inv',
        business.display_name.downcase.gsub("\s",'').first(6),
        random_string
      ].join('-')
    end

    def service_invitation
      @service_invitation ||= find_or_create_service_invitation
    end

    def invitation_link
      ChannelTopics::Person::Invite.invite_link( root_channel_phone_number, service_invitation.code  )
    end

    def welcome_text
      <<~EOW
        Welcome to #{I18n.t(:application_name)}, #{person.display_name}. Here's a quick run down of how it works.

        ---

        🏁 GET STARTED
        First, your going to need to add people. You can invite people by clicking the link or texting #{bold('#invite')}.

        Click the link and send the generated text to your employees. They can click the link and they'll be signed up.

        #{invitation_link}

        To invite more, text #{bold('#invite')}
        sms:#{root_channel_phone_number.to_s(:url)}?body=#invite

        ---

        👥 GROUPS
        Chatting is easiest when you to set up groups. Text #{bold('#add')} with the members names. Here's an example:

        #{bold('#add Joan Smith and @fred to managers')}
        sms:#{root_channel_phone_number.to_s(:url)}?body=#add·

        ---

        💬 CHAT
        Chat with your contacts by texting #{bold('#chat')} along with their names. Add a message you would like to send.

        #{bold('#chat managers, @joansm : Hello!')}
        sms:#{root_channel_phone_number.to_s(:url)}?body=#chat

        ---

        ℹ️ HELP
        There's a lot of other things you can do. If you want a list, text:

        #{bold('#help')}
        sms:#{root_channel_phone_number.to_s(:url)}?body=#help

        ---

        Save the included contact so you can recognize your messages.

        Hope you enjoy texting!
      EOW
    end

    def root_channel_phone_number
      root_channel.channel_people.find{|cp| cp.person_id == person.id }.channel_phone_number
    end

    def root_channel
      @root_channel ||= begin
        attr = { started_by_person_id: person.id, business_id: business.id, topic: Channel::ROOT_TOPIC }
        Channel.where( attr ).first || Channel.new( attr )
      end
    end

  end
end
