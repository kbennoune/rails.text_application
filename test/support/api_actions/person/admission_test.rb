require 'test_helper'

module ApiActions
  module Person
    class AdmissionTest < ActiveSupport::TestCase

      def inviter
        @inviter||= ::Person.create! name: Faker::Name.name, mobile: Faker::PhoneNumber.cell_phone
      end

      def channels
        business.channels
      end

      def business
        @business ||= Business.create!( name: Faker::Company.name, channels: [::Channel.new(people: [inviter, person], topic: ::Channel::ROOT_TOPIC, started_by_person: inviter )] )
      end

      def person
        @person ||= ::Person.create! name: Faker::Name.name, mobile: Faker::PhoneNumber.cell_phone
      end

      def channel_person
        business.root_channel.channel_people.find{|cp| cp.person_id == person.id }
      end

      test 'sends a message to a user' do
        action = ApiActions::Person::Admission.new(inviter, business)
        action.call(person, channels)
        admission_message = action.admission_message
        assert admission_message.persisted?

        generator = TextMessageGenerator.new(channel_person, admission_message, values: { root_phone_number: channel_person.channel_phone_number.to_s(:url) })
        message_text = generator.to_s

        assert_match UnicodeFormatting.format(:bold_italic, inviter.name.titleize), message_text
        assert_match channel_person.channel_phone_number.to_s(:standard), message_text
      end
    end
  end
end
