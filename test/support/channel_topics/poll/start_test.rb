require 'test_helper'

module ChannelTopics
  module Poll
    class StartTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def around(&test)
        UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
          test.call
        end
      end

      def sender
        @sender ||= ::Person.create!( name: 'Jaim Waler', mobile: '2133334444' )
      end

      def people
        @people ||= begin
          [
            ::Person.create!( name: 'Shirley Eastman' ),
            ::Person.create!( name: 'Amal King' ),
            ::Person.create!( name: 'Mervin Nesbit' ),
            ::Person.create!( name: 'Karen Strong-Smith' )
          ].each{|person|
            root_channel.channel_people << ChannelPerson.new( person_id: person.id, application_phone_number: ApplicationPhoneNumber.new(number: '01121321393610') )
          }
        end
      end

      def incoming_message(text,attr={})
        attributes = { message_text: text, message_from: sender.mobile, sender: sender }.merge(attr)
        ::TextMessage.new attributes
      end

      def group1
        @group1 ||= TextGroup.new(name: 'front of the house', business: root_channel.business).tap do |group|
          group.people << people.values_at(0)
          group.save!
        end
      end

      def group2
        @group2 ||= TextGroup.new(name: 'managers', business: root_channel.business).tap do |group|
          group.people << people.values_at(1)
          group.save!
        end
      end

      test 'it will create a channel from people' do
        msg = "#poll #{people[3].name} and #{people[1].name} : What's happening today?"

        topic = ChannelTopics::Poll::Start.new( incoming_message(msg), root_channel )
        topic.call

        assert topic.started_channel.persisted?
        assert_equal 2, topic.started_channel.text_messages.size
        assert_equal [people.values_at(3,1), sender].flatten.to_set, topic.started_channel.people.to_set
      end

      test 'it will create a channel with a group' do
        msg = "#poll front of the house : Are you able to meet tomorrow?"

        group1 = TextGroup.new(name: 'front of the house', business: root_channel.business).tap do |group|
          group.people << people.values_at(0,1)
          group.save!
        end

        topic = ChannelTopics::Poll::Start.new( incoming_message(msg), root_channel )
        topic.call

        assert topic.started_channel.persisted?
        assert_equal 2, topic.started_channel.text_messages.size
        assert_equal [people.values_at(0,1), sender].flatten.to_set, topic.started_channel.people.to_set

      end

      test 'it will create a channel from a group and people' do
        group1
        group2

        msg =  "#poll front of the house, @mervin and managers : What are we going to do today?"

        topic = ChannelTopics::Poll::Start.new( incoming_message(msg), root_channel )
        topic.call

        assert topic.started_channel.persisted?
        assert_equal 2, topic.started_channel.text_messages.size
        assert_equal [people.values_at(0,1,2), sender].flatten.to_set, topic.started_channel.people.to_set

        assert topic.channel_message.persisted?
        assert_match msg.split(' : ').last, generate_text(topic.channel_message)

        assert topic.channel_starter_message.persisted?
        assert_match msg.split(' : ').last, generate_text(topic.channel_starter_message)

      end

    end
  end
end
