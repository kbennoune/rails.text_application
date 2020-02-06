{
  'channel_topics.person.accept.success.inviter' => { escaped_mention_code: proc{|_,params| URI.escape(params[:mention_code]) } },
  'channel_topics.person.accept.welcome' => {
    permanent_chat_section: proc{|key,params|
      if params[:permanent_rooms].blank?
        ''
      else
        new_params = params.merge({
          scope: key.split('.')[0..-2],
          permanent_room_links: params[:permanent_rooms].map{|name,number|
            [ "#{name.titleize}", "sms:#{number}" ].join("\n")
          }.join("\n\n") + "\n"
        })
        I18n.t('welcome_sections.permanent_links', new_params)
      end
    },
    important_links_section: proc{|key,params|
      if params[:important_contacts].blank?
        ''
      else
        new_params = params.merge({
          scope: key.split('.')[0..-2],
          important_chat_links: params[:important_contacts].map{|name,mention|
            [ "#{name.titleize}", "sms:#{params[:root_phone_number]}?body=#{UnicodeFormatting.url_escape(mention)}:" ].join("\n")
          }.join("\n\n")
        })
        I18n.t('welcome_sections.important_links', new_params)
      end
    },
    chat_explanation: proc{|key,params| I18n.t('welcome_sections.chat_explanation', scope: key.split('.')[0..-2])}
  },
  'channel_topics.person.invite.forwardable_invite'=> { italicized_code: proc{|_,params| UnicodeFormatting.format(:italic, params[:code]) } },
  'channel_topics.group.list.list' => { groups_and_number_links: proc{|_,params| params[:groups].map{|group|
     "%{group}\nsms:%{phone_number}?body=%{encoded_body}" % {group: group.titleize, phone_number: params[:root_phone_number], encoded_body: URI.encode("#chat #{group}")}
   }.join("\n\n")}},
  'channel_topics.message.send.recipients' => { sender: proc{|_,_,v| UnicodeFormatting.format(:bold_italic, v.titleize) }},
  'channel_topics.channel.start.success.sender' => { people: proc{|_,_,v| v.map{|name| UnicodeFormatting.format(:italic, name )}.to_sentence(two_words_connector: ' & ', last_word_connector: ' & ') } },
  'channel_topics.channel.start.success.included' => { people: proc{|_,_,v| v.map{|name| UnicodeFormatting.format(:italic, name )}.to_sentence(two_words_connector: ' & ', last_word_connector: ' & ') } },
  'channel_topics.participant.list.root' => { people: [:join, "\n\n"] },
  'channel_topics.participant.list.chat' => { people: [:join, "\n\n"] },
  'channel_topics.group_person.list.list' => { group: proc{|_,_,v| v.titleize }, people: [:join, "\n"] },
  'channel_topics.person.invite.instructions.main' => {
    italicized_code: proc{|_,params| UnicodeFormatting.format(:italic, params[:code]) },
    group_text: proc{|key,p|
      scope = key.split('.')[0..-2]
      new_key = p[:groups].present? ? 'groups_substring' : 'add_groups_substring'
      I18n.t( new_key, scope: scope, groups: p[:groups] )
    },
    refresh_link: proc{|_,params|
      body_part =  UnicodeFormatting.url_escape(["#invite", *(params[:groups] || [])].flatten.compact.join(' '))
      "sms:#{params[:root_phone_number]}?body=" + body_part
    }
  },
  'channel_topics.person.verification.welcome' => {
    example_contacts: proc{|_,params| (params[:important_contacts].present? ? params[:important_contacts] : [[nil,'@artie']]).map{|_,mention| UnicodeFormatting.format(:bold, mention) }.to_sentence(last_word_connector: ' or ') },
    permanent_rooms_section: proc{|key,params|
      if params[:permanent_rooms].present?
        I18n.t('welcome_sections.permanent_rooms_section', params.merge(permanent_rooms_list: params[:permanent_rooms].map{|name,_| name.titleize }.to_sentence, scope: key.split('.')[0..-2]))
      else
        I18n.t('welcome_sections.no_permanent_rooms_section', params.merge( scope: key.split('.')[0..-2]))
      end
    }
  },
  'channel_topics.person.admission.success' => {
    formatted_root_phone_number: proc{|_, params|
      PhoneNumber.new( params[:root_phone_number] ).to_s(:standard)
    },
    included_mentions: proc{|_,params|
      UnicodeFormatting.format(:italic, params[:included_mentions])
    }
  }
}
