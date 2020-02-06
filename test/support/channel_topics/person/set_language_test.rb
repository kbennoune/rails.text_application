require 'test_helper'

module ChannelTopics
  module Person
    class SetLanguageTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def person
        @person ||= ::Person.create!(
          name: 'Shirley Eastman', mobile: '+2482886001'
        ).tap{|person| root_channel.people << person }
      end

      test 'set a language to spanish' do
        text_message = TextMessage.new( message_from: person.mobile, sender: person, message_text: '#espanol')
        action = ChannelTopics::Person::SetLanguage.new(text_message, root_channel)
        action.call

        assert_equal :es, person.reload.preferred_locale
        assert action.success_message.persisted?

        assert lazy_msg = action.success_message.message_generator_keys.find{|elt| elt['key'] == "channel_topics.person.set_language.success"}
        assert_equal 'Español', lazy_msg['values']['language']
        assert_equal '#english', lazy_msg['values']['revert_command']
      end

      test 'set a language to english' do
        person.update_attributes preferred_language: 'es'
        text_message = TextMessage.new( message_from: person.mobile, sender: person, message_text: '#english')
        action = ChannelTopics::Person::SetLanguage.new(text_message, root_channel)
        action.call

        assert_equal :en, person.reload.preferred_locale

        assert action.success_message.persisted?
        assert lazy_msg = action.success_message.message_generator_keys.find{|elt| elt['key'] == "channel_topics.person.set_language.success"}
        assert_equal 'English', lazy_msg['values']['language']
        assert_equal '#español', lazy_msg['values']['revert_command']
      end

      test 'sends an error if the new language is the same as the old' do
        person.update_attributes preferred_language: 'es'
        text_message = TextMessage.new( message_from: person.mobile, sender: person, message_text: '#Español')
        action = ChannelTopics::Person::SetLanguage.new(text_message, root_channel)
        action.call

        assert !action.success_message.persisted?
        assert_equal :es, person.reload.preferred_locale
        assert action.failed_already_set_message.persisted?

        assert lazy_msg = action.failed_already_set_message.message_generator_keys.find{|elt| elt['key'] == "channel_topics.person.set_language.failed.already_set"}
        assert_equal 'Español', lazy_msg['values']['language']
      end

      test "sends an error if the language isn't recognized" do
        text_message = TextMessage.new( message_from: person.mobile, sender: person, message_text: '#Francais')
        action = ChannelTopics::Person::SetLanguage.new(text_message, root_channel)
        action.call

        assert !action.success_message.persisted?
        assert action.failed_language_not_recognized_message.persisted?
        assert_equal :en, person.reload.preferred_locale
      end
    end
  end
end
