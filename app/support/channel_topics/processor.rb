module ChannelTopics
  class Processor
    attr_reader :message, :channel, :route

    delegate :message_text, :message_media, :message_from, to: :message, prefix: false
    delegate :to, :sender, to: :message, prefix: true
    delegate :topic, :business, :started_by_person, to: :channel, prefix: true

    def initialize(message, channel, route={})
      @message = message
      @channel = channel
      @route = route
    end

    def support_number
      PhoneNumber.new('5625999110')
    end

    class << self
      def t(key,args={})
        full_key = (name.underscore.split('/') + [ key ]).join('.')
        I18nLazy.new(full_key, args)
      end
    end

    def t(key,*args)
      self.class.t(key, *args)
    end

    def root_channel
      ::Channel.where( business_id: channel.business_id, topic: ::Channel::ROOT_TOPIC ).first
    end

    def text_message_out( text: nil, message_keys: nil, to: nil, channel: self.channel, **additional_params )
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

      TextMessage.out( params.merge( channel: channel, responding_to_text_message: message ).reverse_merge( additional_params ) )
    end
  end
end
