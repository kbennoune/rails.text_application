require 'test_helper'

module TextChannelWorker
  class CreateTest < ActiveSupport::TestCase
    include ChannelTopics::TestHelpers

    def everyone_group
      @everyone_group ||= TextGroup.create! business: business, name: 'everyone'
    end

    def managers_group
      @management_group ||= TextGroup.create! business: business, name: 'managers'
    end

    def people
      @people ||= restaurant_people.tap{|rps|
        everyone_group.people << rps.values
        managers_group.people << rps.values_at('Jaime Manager', 'Terry Chef')
      }
    end

    def setup
      super
      people
    end

    test 'creates a group channel and populates it with current members of the group' do
      worker = TextChannelWorker::Create.new
      worker.perform( business.id, everyone_group.id )

      Sidekiq::Worker.drain_all

      people.each do |_, person|
        assert everyone_group.channels.first
        assert_includes person.channels, everyone_group.channels.first
      end
    end
  end
end
