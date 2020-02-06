class TextMessageGenerator
  attr_reader :recipient, :text_message, :cache, :additional_values, :header
  delegate :channel, to: :text_message, prefix: nil
  delegate :header_addendum, :sender, :display_header_description?, to: :text_message, prefix: :message

  def initialize(recipient, text_message, cache: {}, values: {}, display_header: true)
    @recipient = recipient
    # recipient is actually a channel person
    @text_message = text_message
    @cache = cache
    @additional_values = values
    @header = display_header ? header_text : nil
  end

  def to_s
    @generated_string ||= if text_message.message_text.present?
      [ header, text_message.message_text].compact.join("\n")
    else
      [ header, generate_localized_message].compact.join("\n")
    end
  end

  def header_text
    if message_sender.present?
      [ message_from_for_header, description_for_header ].find_all(&:present?).join("\n")
    else
      [
        "🦓 " + UnicodeFormatting.format(:bold_italic, I18n.t(:application_name)),
        message_header_addendum
      ].compact.join(' ')
    end
  end

  def message_from_for_header
    base = "👤 #{sender_name_for_header}"
    [base, message_header_addendum].compact.join(' ')
  end

  def sender_name_for_header
    UnicodeFormatting.format(:bold_italic, message_sender.name.titleize)
  end

  def description_for_header
    if message_display_header_description? && !(descriptor = Descriptor.new(channel, message_sender, recipient.person)).blank?
      descriptor.to_s
    end
  end

  class Descriptor
    attr_reader :channel, :sender, :receiver
    delegate :topic, to: :channel, prefix: :channel, allow_nil: true
    delegate :name, to: :receiver, prefix: true, allow_nil: true
    delegate :name, to: :sender, prefix: true, allow_nil: true
    OPEN = '⧼' #'❮'❮
    CLOSE = '⧽' #'❯'

    def initialize( channel, sender, receiver )
      @channel = channel
      @sender = sender
      @receiver = receiver
    end

    def to_s
      if names_for_header.present?
        OPEN +
          UnicodeFormatting.format(:italic, "#{names_for_header.to_sentence(two_words_connector: ' & ', last_word_connector: ' & ')}") +
        CLOSE
      end
    end

    def blank?
      names_for_header.blank?
    end

    def text_group_names
      (channel.try(:text_groups) || []).map{|tg| tg.name }
    end

    def unaffiliated_people
      @unaffiliated_people ||= (channel.channel_people.eager_load(:person).where(added_from_text_group_id: nil).map(&:person) - [receiver]).sort{ |a,b|
        case
        when sender == a
          +1
        when sender == b
          -1
        else
          0
        end
      }
    end

    def unaffiliated_names
      if (unaffiliated_people - [receiver, sender]).present?
        unaffiliated_people.map{|person| person.mention_code(within: channel).gsub(/^@/,'')}
      else
        []
      end
    end

    def raw_names
      @raw_names ||= (unaffiliated_names + text_group_names).compact.map(&:titleize)
    end

    def names_for_header
      @names_for_header ||= if channel_topic == ::Channel::CHAT_TOPIC && raw_names.present?
        descriptor_length = raw_names.sum{|n| n.length + 2 } - 1
        modified_names = if descriptor_length < 25
          raw_names
        else
          cnt = 0
          new_names = raw_names.each_with_index.inject([]) do |acc, (name, idx)|
            trunc = name.truncate(10, omission: '…')

            if trunc.size + cnt < 26
              acc << trunc.tap{|str| cnt += str.length + 2}
            else
              acc << "#{raw_names.size - idx} more"
              break acc
            end

            acc
          end

          new_names
        end

        modified_names
      else
        []
      end
    end
  end

  def localized(run_in_locale=locale,&block)
    begin
      current_locale = I18n.locale
      I18n.locale = run_in_locale || I18n.default_locale
      block.call
    ensure
      I18n.locale = current_locale
    end
  end

  def locale
    recipient.preferred_locale
  end

  def sender_locale
    text_message.original_sender.try(:preferred_locale) || default_locale
  end

  def default_locale
    I18n.locale || Person.new.preferred_locale
  end

  def translation_exists?
    text_message.translation_exists?(locale)
  end

  def default_locale
    I18n.default_locale
  end

  def message_generators
    @message_generators ||= text_message.message_generators.map{|g| g.clone.set_values(additional_values) }
  end

  def message_system_generated?
    # There should be a better way of testing this but it's fine at the moment
    !message_generators.any?{|g| g.values.has_key?(:message) }
  end

  def generate_localized_message
    case
    when message_system_generated? && translation_exists?
      generate_from_translations
    when message_system_generated?
      [ message_generators.join("\n"), joiner_for(locale), google_translation( message_generators.join("\n") ) ].join("\n")
      # translate( localized(default_locale){ message_generators.join("\n") }, locale: locale )
      # generate message for language or generate and translate
    when (sender_locale == locale ) && translation_exists?
      # try to generate in recipient language or generate in default
      generate_from_translations
    when (sender_locale == locale )
      # Weird edge case
      message_generators.join("\n")
    when ( sender_locale != locale ) && translation_exists?
      [  message_generators.map{|g| g.to_s(locale) }.join("\n"), "", joiner_for(locale), "", message_generators.map{|g| g.translate(locale, &translate_values).to_s(locale) } ].join("\n")
    else
      [ message_generators.join("\n"), joiner_for(locale), google_translation( message_generators.join("\n") ) ].join("\n")
    end
  end

  def generate_from_translations
    localized{ message_generators.join("\n")  }
  end

  def translate_values
    proc do |translatable, loc, key, all|
      translatable.map{ |k,v| [ k, google_translation(v,loc).join("\n") ] }.to_h
    end
  end

  def translate(message, locale: )
    [message, joiner_for(locale), google_translation( message ).join("\n")].join("\n")
  end

  def joiner_for(locale)
    I18n.t(:translation_header, default: '', locale: locale)
  end

  def google_translation(message, loc=locale)
    cache[ cache_key(loc,message) ] ||= translation_client.translate(message, locale, sender_locale)
  end

  def cache_key(*strings)
    Digest::SHA256.hexdigest( strings.join )
  end

  def translation_client
    @translation_client ||= Translation::GoogleApi.new
  end
end
