require 'test_helper'

module ChannelTopics
  module Channel
    class StartTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def around(&test)
        UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
          test.call
        end
      end

      def incoming_message_with(attrs={})
        ::TextMessage.new attrs
      end

      def sender
        @sender ||= ::Person.create!( name: 'Jaim Waler', mobile: '2133334444' ).tap{|person|
          root_channel.channel_people << ChannelPerson.new( person_id: person.id, application_phone_number: ApplicationPhoneNumber.new(number: '01121321393610') )
        }
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

      def message_formats(recipients, message)
        [
          "#chat with #{recipients}\n#{message}",
          "#chat #{recipients}: #{message}"
        ]
      end

      def outgoing_message
        "Hey, is this an outgoing message?\nI think it is..."
      end

      def group1
        @group1 ||= TextGroup.new(name: 'first group', business: root_channel.business).tap do |group|
          group.people << additional_people[0..3]
          group.save!
        end
      end

      def group2
        @group2 ||= TextGroup.new(name: 'second-group', business: root_channel.business).tap do |group|
          group.people << additional_people[3..-1]
          group.save!
        end
      end

      def additional_people
        @additional_people ||= restaurant_people.values.each{|person| person.channels << root_channel }
      end

      test 'it will create a channel with a single user' do
        msg = "#chat with #{people.last.name}"
        incoming_message = incoming_message_with message_text: msg, message_from: sender.mobile, sender: sender

        topic = ChannelTopics::Channel::Start.new(incoming_message, root_channel)
        topic.call

        assert topic.started_channel.persisted?
        assert_equal 2, topic.started_channel.text_messages.size
        assert_equal [people.last, sender].sort, topic.started_channel.people
      end

      test 'it will create a channel with multiple people' do
        message_formats(people.map(&:name).join(', '), outgoing_message).each do |msg|
          incoming_message = incoming_message_with message_text: msg, message_from: sender.mobile, sender: sender

          topic = ChannelTopics::Channel::Start.new(incoming_message, root_channel)
          topic.call

          assert topic.started_channel.persisted?

          assert 2, topic.action.messages.find_all(&:persisted?).size
          assert_equal [topic.started_channel], topic.action.messages.map(&:channel).uniq

          assert_match '#STOP', normalized(generate_text(topic.started_channel.text_messages.first))
          assert_match outgoing_message, generate_text(topic.started_channel.text_messages.first)
          assert_equal (people.map(&:name) + [sender.name]).sort, topic.started_channel.people.map(&:name).sort
        end
      end

      test 'it will create a channel from an existing group and users' do
        group1
        group2

        msg = "#chat #{group2.name}, #{people[1].name}, #{group1.name}, #{people[2].name} : Is everyone there?"
        incoming_message = incoming_message_with message_text: msg, message_from: sender.mobile, sender: sender

        topic = ChannelTopics::Channel::Start.new(incoming_message, root_channel)
        topic.call

        assert topic.started_channel.persisted?
        assert_equal 2, topic.started_channel.text_messages.size
        assert_equal ([sender] + additional_people + people[1..2]).flatten.to_set, topic.started_channel.people.to_set
      end
    end

    class StartFromAtSignTest < StartTest
      def incoming_message(text,attr={})
        attributes = { message_text: text, message_from: sender.mobile, sender: sender }.merge(attr)
        ::TextMessage.new attributes
      end

      test 'it will create a new channel from a list of mentions with text' do
        people
        ['@shirley @amal This is a new text!', '@shirley @amal: This is a new text!', '@shirley @amal : This is a new text!', '@shirley, amal : This is a new text!', '@shirley, amal:This is a new text!'].each do |msg|

          topic = ChannelTopics::Channel::Start.new( incoming_message(msg), root_channel )
          topic.call

          assert topic.started_channel.persisted?
          assert 2, topic.action.messages.find_all(&:persisted?).size
          assert_equal [topic.started_channel], topic.action.messages.map(&:channel).uniq

          assert_equal [people.values_at(0,1), sender].flatten.to_set, topic.started_channel.people.to_set
          assert topic.channel_message.persisted?
          assert_match 'This is a new text!', generate_text(topic.channel_starter_message)
        end
      end

      test 'it will create a new channel from a comma seperated list of people' do
        people
        msg = '#chat shirley,amal'

        topic = ChannelTopics::Channel::Start.new( incoming_message(msg), root_channel )
        topic.call

        assert topic.started_channel.persisted?
        assert_equal 2, topic.started_channel.text_messages.size

        assert_equal [people.values_at(0,1), sender].flatten.to_set, topic.started_channel.people.to_set
        assert topic.channel_message.persisted?
        assert_match msg.gsub('#chat ',''), generate_text(topic.channel_starter_message)
        assert_match people[0].name, normalized( generate_text(topic.channel_starter_message) )
        assert_match people[1].name, normalized( generate_text(topic.channel_starter_message) )

      end


      test 'it will create a new channel from a list of mentions' do
        people
        msg = '@shirley @amal'

        topic = ChannelTopics::Channel::Start.new( incoming_message(msg), root_channel )
        topic.call

        assert topic.started_channel.persisted?
        assert_equal 2, topic.started_channel.text_messages.size

        assert_equal [people.values_at(0,1), sender].flatten.to_set, topic.started_channel.people.to_set
        assert topic.channel_message.persisted?
        assert_match people[0].name, normalized( generate_text(topic.channel_starter_message) )
        assert_match people[1].name, normalized( generate_text(topic.channel_starter_message) )

      end

      test 'it will use an existing channel if there is a matching active channel' do
        people
        msg1 = '@shirley @amal this is message 1'

        topic1 = ChannelTopics::Channel::Start.new( incoming_message(msg1), root_channel )
        topic1.call

        msg2 = '@shirley @amal this is message 2'
        topic2 = ChannelTopics::Channel::Start.new( incoming_message(msg2), root_channel )

        topic2.call
        assert_equal topic1.started_channel, topic2.started_channel
      end
    end
  end
end
