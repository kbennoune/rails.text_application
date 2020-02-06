module ChannelTopics
  module Person
    class SetLanguage < ChannelTopics::Processor
      LANGUAGES = {
        'en': ['English', /#[Ee]nglish/],
        'es': ['Español', /#[Ee]spa[nñ]ol/]
      }

      def call
        ::Person.transaction do
          if requested_language.present?
            if message_sender.preferred_language != requested_language
              message_sender.preferred_language = requested_language
              message_sender.save!
              success_message.save!
            else
              failed_already_set_message.save!
            end
          else
            failed_language_not_recognized_message.save!
          end
        end
      end

      def original_language
        case
        when message_sender.previous_changes.present?
          message_sender.previous_changes.dig('preferred_language', 0)
        when message_sender.changes.present?
          message_sender.changes.dig('preferred_language', 0)
        else
          message_sender.preferred_language
        end
      end

      def requested_language
        if lang_definition = LANGUAGES.find{|key,(_,regex)| regex === message_text }
          lang_definition.first.to_s
        end
      end

      def success_message
        @success_message ||= text_message_out to: :sender, message_keys: t('success', language: language_name(requested_language), revert_command: revert_command(original_language))
      end

      def failed_already_set_message
        @failed_already_set_message ||= text_message_out to: :sender, message_keys: t('failed.already_set', language: language_name(message_sender.preferred_language))
      end

      def failed_language_not_recognized_message
        @failed_language_not_recognized_message ||= text_message_out to: :sender, message_keys: t('failed.not_recognized')
      end

      def revert_command(code)
        revert_language_name = language_name(code) || language_name(:en)

        "##{revert_language_name.downcase}"
      end

      def language_name(code)
        if code && lang_definition = LANGUAGES[code.to_sym]
          lang_definition[0]
        end
      end
    end
  end
end
