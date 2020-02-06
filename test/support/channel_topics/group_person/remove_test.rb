require 'test_helper'

module ChannelTopics
  module GroupPerson
    class RemoveTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def around(&test)
        UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
          test.call
        end
      end

      def people
        @people ||= restaurant_people.each{|_,person| root_channel.people << person }
      end

      def rem_from_group_command(*groups)
        "#remove #{people.values[1].name} from #{groups.join(', ')}"
      end

      def rem_people_from_group_cmd(people=[], groups=[])
        "#add #{people.map(&:name).join(', ')} from #{groups.join(', ')}"
      end

      test 'removing a user by name' do
        existing_group = TextGroup.create!( business: business, name: 'managers' )
        existing_group.people << people.values[1]

        text_message = TextMessage.create! message_text: rem_from_group_command('managers'), channel: root_channel
        topic = ChannelTopics::GroupPerson::Remove.new text_message, root_channel
        topic.call

        assert !existing_group.people.include?(people.values[1])
      end

      test 'remove multiple users from multiple groups' do
        people_to_remove = people.values[1..3]
        existing_groups = [
          TextGroup.new( business: business, name: 'managers' ),
          TextGroup.new( business: business, name: 'kitchen cleaners' ),
          TextGroup.new( business: business, name: 'front-of-the-house' )
        ].each do |group|
          group.people << people_to_remove

          group.save!
        end

        text_message = TextMessage.create!(
           message_text: rem_people_from_group_cmd(people_to_remove, existing_groups.map(&:name)),
           channel: root_channel
         )
         topic = ChannelTopics::GroupPerson::Remove.new text_message, root_channel
         topic.call

         existing_groups.each do |existing_group|
           people_to_remove.each do |person|
             assert !existing_group.reload.people.include?(person)
           end
         end
      end
    end
  end
end
