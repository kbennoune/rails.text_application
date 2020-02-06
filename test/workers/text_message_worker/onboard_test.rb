require 'test_helper'

module TextMessageWorker
  class OnboardTest < ActiveSupport::TestCase
    include ChannelTopics::TestHelpers

    def business
      @business ||= Business.create! facebook_place: FacebookPlace.new(name: 'This is a business name')
    end

    def person
      @person ||= Person.create! mobile: '2123334444', name: 'Customer Johnson'
    end

    test 'adds a person to a new channel and sends some help' do
      worker = TextMessageWorker::Onboard.new

      worker.perform person.id, business.id

      channel_relation = Channel.where(
        business_id: business.id,
        topic: Channel::ROOT_TOPIC
      )

      assert channel_relation.exists?
      assert_equal person, channel_relation.first.people.first

      text_relation = TextMessage.where( channel: channel_relation.first )
      assert_equal 1, text_relation.size

      assert_match /[Ww]elcome/, normalized(text_relation.first.message_text)
      assert_match '#chat', normalized(text_relation.first.message_text)
      assert_equal 1, TextMessageWorker::Send.jobs.find_all{|j| j['args'][0] == text_relation.first.id }.size
    end

    test 'adds a person to an existing channel and sends some help' do
      worker = TextMessageWorker::Onboard.new
      channel = ::Channel.create! started_by_person: person, business: business, topic: Channel::ROOT_TOPIC
      worker.perform person.id, business.id

      channel_relation = Channel.where(
        business_id: business.id,
        topic: Channel::ROOT_TOPIC
      )

      assert_equal channel_relation.last, channel
      assert_equal person, channel_relation.first.people.first

      text_relation = TextMessage.where( channel: channel_relation.last )
      assert_equal 1, text_relation.size
      assert_match /[Ww]elcome/, normalized(text_relation.first.message_text)
      assert_match '#chat', normalized(text_relation.first.message_text)
      assert_equal 1, TextMessageWorker::Send.jobs.find_all{|j| j['args'][0] == text_relation.first.id }.size
    end

    test 'it rolls back a transaction that throws an error' do
      worker = TextMessageWorker::Onboard.new
      worker.instance_variable_set(:@person, person)
      worker.instance_variable_set(:@business, business)

      worker.stub(:onboard_message_media, []) do
        worker.stub(:root_channel_phone_number, PhoneNumber.new('1234567890')) do
          worker.root_channel.stub(:valid?, false) do
            assert_raise{ worker.perform( person.id, business.id ) }
            assert !ChannelPerson.joins(:channel).where( person_id: person.id, channels: { business_id: business.id }).exists?
            assert !ChannelPerson.where(person_id: person.id).exists?
            assert !Channel.where( business_id: business.id ).exists?
            assert TextMessageWorker::Send.jobs.blank?
          end
        end
      end
    end

    test 'it sends a contact file with the text message' do
      worker = TextMessageWorker::Onboard.new
      channel = ::Channel.create! business: business, topic: Channel::ROOT_TOPIC
      worker.perform person.id, business.id

      assert worker.onboard_text.persisted?
      assert worker.onboard_text.message_media.grep(/\/contacts\/\d+\/\d+\/app/).present?
      assert worker.onboard_text.message_media.grep( Regexp.new('http://test.text_application.com') ).present?

    end

    test 'it can be run multiple times for the same user' do
      worker = TextMessageWorker::Onboard.new
      channel = ::Channel.create! business: business, topic: Channel::ROOT_TOPIC, started_by_person: person
      worker.perform person.id, business.id

      worker2 = TextMessageWorker::Onboard.new
      worker.perform person.id, business.id

      assert_equal 1, channel.channel_people.where( person_id: person.id ).size
    end
  end
end
