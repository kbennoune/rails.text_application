require 'test_helper'

module ChannelTopics
  module Person
    class CreateTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def vcard_string
        <<-EOV
        BEGIN:VCARD
        VERSION:3.0
        N:Ganguly;Anik
        FN:Anik Ganguly
        ORG: Open Text Inc.
        ADR;TYPE=WORK,POSTAL,PARCEL:;Suite 101;38777 West Six Mile Road;Livonia;MI;48152;USA
        TEL;TYPE=WORK,MSG,CELL:+1-734-542-5955
        EMAIL;TYPE=INTERNET:ganguly@testuser.org
        END:VCARD
        EOV
      end

      def text_message
        @text_message ||= new_text_message(message_media: ['http://bandwith/file/named/contact1.vcf'])
      end

      def call_topic(text_message, channel, vcard_string)
        topic = ChannelTopics::Person::Create.new(text_message, channel)
        Bandwidth::Media.stub(:download, Proc.new{|_,file| text_message.message_media.first.match( file ) ? [vcard_string] : raise("#{file} should match #{message.message_media.first}") }) do
          topic.call
        end
        topic
      end

      class AddContactFileToGroup < CreateTest

        def text_message
          @text_message ||= new_text_message(message_text: add_to_groups_message, message_media: ['http://bandwith/file/named/contact1.vcf'])
        end

        def add_to_groups_message
          "add to managers, kitchen staff"
        end

        test 'adds a new contact to a group' do
          topic = call_topic(text_message, chat_channel, vcard_string)

          assert topic.person.previous_changes.present?
          assert_equal topic.person.previous_changes[:name].last, 'Anik Ganguly'
          assert_equal topic.person.previous_changes[:email].last, 'ganguly@testuser.org'

          group_memberships = TextGroupPerson.joins(:person).where( people: { email: 'ganguly@testuser.org' })
          assert group_memberships.find{|gm| gm.text_group.name == 'managers' }
          assert group_memberships.find{|gm| gm.text_group.name == 'kitchen staff' }

          assert_equal 2, group_memberships.size
        end


      end

      class WithContactFile < CreateTest
        test 'adds a new person' do
          topic = call_topic(text_message, chat_channel, vcard_string)

          assert topic.person.previous_changes.present?
          assert_equal topic.person.previous_changes[:name].last, 'Anik Ganguly'
          assert_equal topic.person.previous_changes[:email].last, 'ganguly@testuser.org'
        end

        test 'links the person to the channel' do
          topic = call_topic(text_message, chat_channel, vcard_string)
          assert ChannelPerson.where(channel_id: chat_channel.id, person_id: topic.person.id).exists?
        end

        class MatchingExistingPhoneNumber < CreateTest
          def person
            @person ||= ::Person.create! mobile: '1-734-542-5955', name: 'wrong name', email: 'old email'
          end

          test 'updates the existing contact' do
            person
            topic = call_topic(text_message, chat_channel, vcard_string)
            person.reload

            assert_equal 'Anik Ganguly', person.name
            assert_equal 'ganguly@testuser.org', person.email
          end

          test 'will not create a new channel record' do
            person
            topic = call_topic(text_message, chat_channel, vcard_string)
            ChannelPerson.where( person_id: person.id ).tap do |channel_links|
              assert_equal 1, channel_links.size
              assert_equal chat_channel.id, channel_links[0][:channel_id]
            end
          end
        end

        class MatchingExistingName < CreateTest
          def person
            @person ||= ::Person.create! mobile: '0112132323234', name: 'Anik Ganguly', email: 'old email'
          end

          test 'updates the existing contact' do
            person
            topic = call_topic(text_message, chat_channel, vcard_string)
            person.reload
            assert_equal person.mobile, '1-734-542-5955'
            assert_equal 'ganguly@testuser.org', person.email
          end

        end
      end

      class WithTextedContact < CreateTest
        def message_text
          <<-EOT
          Add #{contact_name}
          #{phone_number}
          #{email}
          EOT
        end

        def contact_name
          'Gilberto Aparecido da Silva'
        end

        def phone_number
          '(432) 563-5555'
        end

        def email
          'gilberto@arsenal.com'
        end


        def text_message
          TextMessage.new message_text: message_text
        end

        test 'adds a new contact' do
          topic = call_topic(text_message, chat_channel, vcard_string)
          assert topic.person.persisted?
          assert_equal topic.person.name, contact_name
          assert_equal topic.person.email, email
          assert_equal topic.person.mobile, PhoneNumber.new(phone_number)
        end
      end

      class ContactInfoFromMessage < CreateTest
        def formats(name,email,phone,group)
          [
            "#add #{name}\n #{email}\n  #{phone}\nto #{group}",
            "Add #{phone}\n#{name} to #{group}",
            "Save contact #{phone}:#{name}"
          ]
        end

        def contact_name
          'Frank de Boer'
        end

        def phone_number
          # PhoneNumber.new('0116434774000')
          PhoneNumber.new('(313) 454-6767')
        end

        def group
          'managers'
        end

        def groups
          ['managers', 'kitchen staff']
        end

        def email
          'frank@holland.national.com'
        end

        def failure_message(attribute, format)
          "#{attribute.to_s.capitalize} comprehension failed for '#{format.gsub("\n","\\n")}'"
        end

        test 'saves a number of formats correctly' do
          formats(contact_name, email, phone_number, group).each do |format|
            text_message = TextMessage.new(message_text: format)
            topic = ChannelTopics::Person::Create.new(text_message, chat_channel)
            contact_info = topic.contact_info_from_text
            assert_equal contact_info[:name], contact_name, failure_message(:name, format)
            assert_equal PhoneNumber.new(contact_info[:mobile]), phone_number, failure_message(:email, format)
          end
        end

        test 'it adds a contact to a new group' do
          formats = [
            "#add #{phone_number}\n#{contact_name} to #{groups.to_sentence(two_words_connector: ' & ', last_word_connector: ' & ')}",
            "#add #{phone_number}\n#{contact_name} to #{groups.join(', ')}",
            "#add #{phone_number}\n#{contact_name} to #{groups.join(',')}"
          ].each do |format|
            text_message = TextMessage.new(message_text: format)
            topic = ChannelTopics::Person::Create.new(text_message, chat_channel)
            topic.call

            group_memberships = TextGroupPerson.joins(:person).where( people: { name: contact_name })
            assert group_memberships.find{|gm| gm.text_group.name == 'managers' }
            assert group_memberships.find{|gm| gm.text_group.name == 'kitchen staff' }

            assert_equal 2, group_memberships.size
          end
        end

        test 'it adds a contact to an existing group' do
          existing_group = TextGroup.create! business: business, name: groups.last
          format = "#add #{phone_number}\n#{contact_name} to #{groups.to_sentence(two_words_connector: ' & ', last_word_connector: ' & ')}"
          text_message = TextMessage.new(message_text: format)
          topic = ChannelTopics::Person::Create.new(text_message, chat_channel)
          topic.call

          group_memberships = TextGroupPerson.joins(:person).where( people: { name: contact_name })
          assert group_memberships.find{|gm| gm.text_group.name == 'managers' }
          assert group_memberships.find{|gm| gm.text_group.name == 'kitchen staff' }
          assert_equal existing_group.id, group_memberships.find{|gm| gm.text_group.name == 'kitchen staff' }.text_group.id

          assert_equal 2, group_memberships.size
        end

        def manager
          @manager ||= ::Person.create! name: "The manager", mobile: '3331234567'
        end

        test 'it sends a response message to the user' do
          # existing_group = TextGroup.create! business: business, name: groups.last
          format = "#add #{phone_number}\n#{contact_name} to #{groups.to_sentence(two_words_connector: ' & ', last_word_connector: ' & ')}"
          text_message = TextMessage.new(message_text: format, message_from: manager.mobile, sender: manager )

          topic = ChannelTopics::Person::Create.new(text_message, chat_channel)
          topic.call

          response = TextMessage.where( to: [ manager.mobile ] ).first

          assert response
          assert_match 'managers and kitchen staff', generate_text(response)

        end
      end
    end
  end
end
