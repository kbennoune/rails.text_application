module TextMessageWorker
  class Send
    include Sidekiq::Worker

    attr_reader :text_message

    # Sets the channel for the message

    def perform(text_message_id)
      @text_message = TextMessage.find(text_message_id)
      if app_status_queued?
        process_text_message
      end
    end

    def app_status_queued?
      text_message.app_status == TextMessage::APP_STATUS_QUEUED
    end

    def process_text_message
      responses = TextMessage.transaction do
        text_message.update( app_status: TextMessage::APP_STATUS_SENT )

        send_message_to_recipients
      end

      if responses.present?
        response = [responses].flatten.first

        text_message.update(
          {
            message_id: response[:message_id] || response[:id],
            remote_state: response[:remote_state],
            remote_sending_time: response[:time],
            remote_events: text_message.remote_events + [response]
          }.compact
        )
      end

      response
    end

    def send_message_to_recipients
      base_params = {
        media: text_message.message_media, text: text_message.message_text
      }

      message_params = recipients.map do |recipient|
        base_params.merge( to: recipient.sms_number, from: recipient.channel_phone_number, text: message_text_for(recipient, text_message) )
      end

      if Rails.application.config.x.short_host.present?
        base_params[:callback_url] = Rails.application.routes.url_helpers.callback_bandwidth_endpoints_mms_url(
          host: Rails.application.config.x.short_host, protocol: Rails.application.config.x.short_host_protocol,
          only_path: false, user: Rails.application.secrets.bandwidth_callback_auth[:name],
          password: Rails.application.secrets.bandwidth_callback_auth[:password]
        )
      end

      create_text_message(message_params)
    end

    def recipients
      if text_message.channel.present?
        recipients_from_channel
      else
        # This is usually to a number
        # that texted the app but isn't
        # in the system
        recipients_from_phone_numbers
      end
    end

    def recipients_from_phone_numbers
      text_message.to.map do |to|
        OpenStruct.new( preferred_locale: I18n.locale, sms_number: to, channel_phone_number: text_message.message_from, root_application_phone_number: text_message.message_from )
      end
    end

    def recipients_from_channel
      if text_message.to.present?
        text_message.channel.channel_people.active.expanded_recipients.find_all{|recipient| [text_message.to].flatten.include?(recipient.sms_number) }
      else
        text_message.channel.channel_people.active.expanded_recipients.reject{|recipient| recipient.sms_number == text_message.original_message_from }
      end
    end

    def message_text_for(recipient, text_message)
      additional_values = { channel_phone_number: recipient.channel_phone_number.to_s(:url) }
      if recipient.root_application_phone_number.present?
        additional_values[ :root_phone_number ] = recipient.root_application_phone_number.to_s(:url)
      end
      TextMessageGenerator.new(recipient, text_message, cache: translation_cache, values: additional_values).to_s
    end

    def translation_cache
      @translation_cache ||= {}
    end

    def create_text_message(message_params)
      Bandwidth::Message.create(client, message_params)
    end

    def client
      @client ||= Bandwidth::Client.new Rails.application.secrets.bandwidth
    end

  end
end
