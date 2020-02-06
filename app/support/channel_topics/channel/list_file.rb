module ChannelTopics
  module Channel
    class ListFile < ChannelTopics::Processor

      def call
        list_message.save!
      end

      def list_message
        @list_message ||= text_message_out to: :sender, message_keys: list_text, media: [ contact_file_url ]
      end

      def list_text
        t('explanation', business_name: channel_business.display_name )
      end

      def contact_file_url
        Rails.application.routes.url_helpers.app_contact_card_with_name_url( host: Rails.application.config.x.short_host, protocol: 'http', only_path: false, business_id: channel_business.id, person_id: message_sender.id, filename: Addressable::URI.encode("#{channel_business.display_name} Texting"), format: :vcf, skip: :ssl )
      end
    end
  end
end
