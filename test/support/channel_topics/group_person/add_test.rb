require 'test_helper'

module ChannelTopics
  module GroupPerson
    class AddTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def around(&test)
        UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
          test.call
        end
      end

      def people
        @people ||= restaurant_people.each{|_,person| root_channel.people << person }
      end

      def add_to_group_command(*groups)
        "#add #{people.values[1].name} to #{groups.join(', ')}"
      end

      def add_people_to_group_cmd(people=[], groups=[])
        "#add #{people.map(&:name).join(', ')} to #{groups.join(', ')}"
      end

      test 'adds a person to an existing group' do
        existing_group = ::TextGroup.create! name: 'managers', business: business
        text_message = TextMessage.create! message_text: add_to_group_command('managers'), channel: root_channel
        topic = ChannelTopics::GroupPerson::Add.new text_message, root_channel
        topic.call

        assert existing_group.people.include? people.values[1]
      end

      test 'adds a person to a new group' do
        text_message = TextMessage.create! message_text: add_to_group_command('kitchen staff'), channel: root_channel
        topic = ChannelTopics::GroupPerson::Add.new text_message, root_channel
        topic.call

        new_group_rel = TextGroup.where( name: 'kitchen staff', business: business ).all
        assert_equal 1, new_group_rel.size
        assert new_group_rel.first.people.include?(people.values[1])
      end

      test 'adds a person to a group with a dash' do
        text_message = TextMessage.create! message_text: add_to_group_command('kitchen-staff'), channel: root_channel
        topic = ChannelTopics::GroupPerson::Add.new text_message, root_channel
        topic.call

        new_group_rel = TextGroup.where( name: 'kitchen-staff', business: business ).all
        assert_equal 1, new_group_rel.size
        assert new_group_rel.first.people.include?(people.values[1])
      end

      test 'adds a person to multiple groups' do
        existing_group = ::TextGroup.create! name: 'managers', business: business

        text_message = TextMessage.create! message_text: add_to_group_command('managers', 'kitchen staff'), channel: root_channel
        topic = ChannelTopics::GroupPerson::Add.new text_message, root_channel
        topic.call

        new_group_rel = TextGroup.where( name: 'kitchen staff', business: business ).all
        assert_equal 1, new_group_rel.size
        assert new_group_rel.first.people.include?(people.values[1])
        assert existing_group.people.include? people.values[1]
      end

      test 'adds multiple people to multiple groups' do
        existing_group = ::TextGroup.create! name: 'managers', business: business
        people_to_add = people.values[1..2]
        text_message = TextMessage.create! message_text: add_people_to_group_cmd(people_to_add, ['managers', 'kitchen staff']), channel: root_channel
        topic = ChannelTopics::GroupPerson::Add.new text_message, root_channel
        topic.call

        new_group_rel = TextGroup.where( name: 'kitchen staff', business: business ).all
        assert_equal 1, new_group_rel.size
        assert new_group_rel.first.people.include?(people.values[1])
        assert existing_group.people.include? people.values[1]
        assert new_group_rel.first.people.include?(people.values[2])
        assert existing_group.people.include? people.values[2]
      end
    end
  end
end
