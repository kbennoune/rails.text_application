require 'test_helper'

module ChannelTopics
  module Participant
    class ListTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def setup
        super
        chat_channel.business.update_attributes( name: business_name )
      end

      def incoming_message
        ::TextMessage.new message_text: list_message_text, message_from: message_sender.mobile, sender: message_sender
      end

      def list_message_text
        '#list'
      end

      def message_sender
        people.first
      end

      def business_name
        "This is a business!"
      end

      def people
        @people ||= [
          ::Person.create!( name: 'Mary Shelly', mobile: '+7778881234' ),
          ::Person.create!( name: 'Shirley Eastman', mobile: '+2482886001' ),
          ::Person.create!( name: 'Amal King', mobile: '+2482886002' ),
          ::Person.create!( name: 'Mervin Nesbit', mobile: '+2482886003' ),
          ::Person.create!( name: 'Karen Strong-Smith', mobile: '+2482886004' )
        ].each_with_index do |person,idx|
          root_channel.channel_people << ChannelPerson.new( person_id: person.id )
          if idx <= 2
            chat_channel.channel_people << ChannelPerson.new( person_id: person.id )
          end
        end
      end

      test 'it sends a list of all of the contacts' do
        topic = ChannelTopics::Participant::List.new(incoming_message, root_channel)

        topic.call
        channel_messages = TextMessage.where( channel_id: root_channel )
        assert_equal 1, channel_messages.size
        assert_match business_name, generate_text(channel_messages.first)
        people.each do |person|
          assert_match person.name, generate_text(channel_messages.first)
        end
      end

      test 'it sends a list of everyone on the channel' do
        topic = ChannelTopics::Participant::List.new(incoming_message, chat_channel)

        topic.call
        channel_messages = TextMessage.where( channel_id: chat_channel )
        assert_equal 1, channel_messages.size

        people.first(3).each do |person|
          assert_match person.name, generate_text(channel_messages.first)
        end

        people.last(2).each do |person|
          assert !generate_text(channel_messages.first).match(person.name)
        end
      end

      test 'it sends a list of everyone in the root channel with #list all' do
        incoming_message = ::TextMessage.new message_text: '#list all', message_from: message_sender.mobile, sender: message_sender
        ::Person.bulk_update_fuzzy_name

        topic = ChannelTopics::Participant::List.new(incoming_message, chat_channel)
        topic.call

        listed_people = topic.list_message.message_generator_keys[0].values.last['people'].map{|entry| entry.gsub(/\n@\S+/,'')}
        listed_mention_codes = topic.list_message.message_generator_keys[0].values.last['people'].map{|entry| entry.match(/(@\S+)/).to_s }

        assert_equal root_channel.people.map(&:display_name).to_set, listed_people.to_set
        assert_equal root_channel.people.map{|p| '@' + p.display_name.split("\s").first.downcase }.to_set, listed_mention_codes.to_set
      end
    end
  end
end
