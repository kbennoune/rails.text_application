module Translation
  class GoogleApi
    attr_reader :client

    class << self
      def get_api_client(api_key=Rails.application.secrets.google[:api_key])
        Google::Apis::TranslateV2::TranslateService.new.tap do |svc|
          svc.key = api_key
        end
      end
    end

    def initialize(client=self.class.get_api_client)
      @client = client
    end

    def translate(text, target_language, source_language=nil, format: 'text', model: nil)
      # The source language can be skipped
      text_request = Google::Apis::TranslateV2::TranslateTextRequest.new( format: 'text', q: [ text ], source: source_language, target: target_language, model: model )
      response = client.translate_translation_text(text_request)

      TranslationResponse.collection( response, target_language, source_language )
    end

    class TranslationResponse
      class << self
        def collection(response, target, source)
          response.translations.map{|translation| self.new(translation, target, source)}
        end
      end

      attr_reader :translations_resource, :locale, :source_locale

      def initialize(translations_resource, requested_locale, source_language=nil)
        @translations_resource = translations_resource
        @locale = requested_locale.to_s.to_sym
        @source_locale = (translations_resource.detected_source_language || source_language).to_s.to_sym
      end

      def text
        translations_resource.translated_text
      end

      def to_s
        text
      end
    end
  end
end
