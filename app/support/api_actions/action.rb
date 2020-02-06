module ApiActions
  module Action
    def t(key, *args)
      relative_name = [ 'ChannelTopics', self.class.name.split('::')[1..-1] ].flatten.join('::')
      if (konstant = relative_name.safe_constantize)
        konstant.t(key, *args)
      else
        full_key = [relative_name.underscore.split('/'), key].flatten.compact.join('.')
        I18nLazy.new(full_key, *args)
      end
    end

    # can be overriden in including classes
    def parent_message
    end

    def text_message_out( text: nil, message_keys: nil, to: nil, channel: nil, **additional_params )
      params = if to == :sender
        {
          message_text: text, message_generator_keys: message_keys,
          original_from: message_from, to: message_from
        }
      else
        {
          to: to, message_text: text, message_generator_keys: message_keys,
          original_from: message_from
        }.compact
      end

      TextMessage.out( params.merge( channel: channel, responding_to_text_message: parent_message ).reverse_merge( additional_params ) )
    end
  end
end
