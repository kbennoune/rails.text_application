require 'test_helper'

module ChannelTopics
  module Alias
    class SetTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def around(&test)
        UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
          test.call
        end
      end

      def people
        @people ||= restaurant_people.each{|_,rec| rec.channels << root_channel; rec.save! }
      end

      test 'sets a user to be an alias' do
        on_duty_manager = ::Person.create! name: 'manager on duty', channels: [ root_channel ]
        message_text = '#set @onduty to @jaime'
        text_message = ::TextMessage.new(
          message_text: message_text, message_from: people['Terry Chef']
        )
        processor = ::ChannelTopics::Alias::Set.new( text_message, root_channel ).tap(&:call)

        assert_equal [people['Jaime Manager']], on_duty_manager.reload.active_real_people
      end

      test 'sets multiple users to be an alias' do
        on_duty_manager = ::Person.create! name: 'manager on duty', channels: [ root_channel ]
        message_text = '#set @onduty to @jaime @terry'
        text_message = ::TextMessage.new(
          message_text: message_text, message_from: people['Terry Chef']
        )
        processor = ::ChannelTopics::Alias::Set.new( text_message, root_channel ).tap(&:call)

        assert_equal people.values_at('Jaime Manager', 'Terry Chef'), on_duty_manager.reload.active_real_people
      end

      test 'resets users to be an alias' do
        on_duty_manager = ::Person.create! name: 'manager on duty', channels: [ root_channel ]
        message_text = '#set @onduty to @jaime @terry'
        text_message = ::TextMessage.new( message_text: message_text, message_from: people['Terry Chef'] )
        processor = ::ChannelTopics::Alias::Set.new( text_message, root_channel ).tap(&:call)

        assert_equal people.values_at('Jaime Manager', 'Terry Chef'), on_duty_manager.reload.active_real_people

        message_text = '#set @onduty to @francis @terry'
        text_message = ::TextMessage.new( message_text: message_text, message_from: people['Terry Chef'] )
        processor = ::ChannelTopics::Alias::Set.new( text_message, root_channel ).tap(&:call)

        assert_equal people.values_at('Francis Dishwasher', 'Terry Chef').to_set, on_duty_manager.reload.active_real_people.to_set
      end
    end
  end
end
