require 'test_helper'
require 'controllers/data_api/controller_test_helper.rb'

module DataApi
  class ChannelsControllerTest < ActionDispatch::IntegrationTest
    include ControllerTestHelper

    def manager
      @manager ||= Person.create! name: 'manager'
    end

    def business
      @business ||= Business.create!.tap do |business|
        business.channels.create!( topic: ::Channel::ROOT_TOPIC, started_by_person: manager )

        business.channels.create!( topic: ::Channel::CHAT_TOPIC ).tap do |chat_channel|
          chat_channel.text_messages.create! message_text: 'This is message 1', message_generator_key: 'a.generator.key'
          chat_channel.text_messages.create! message_text: 'This is message 2', message_generator_key: 'a.generator.key'
          chat_channel.channel_groups.create!( text_group: TextGroup.new )
          #Should be ignored
          chat_channel.channel_groups.create!( text_group: TextGroup.new )
        end

        business.channels.create!( topic: ::Channel::ROOM_TOPIC ).tap do |room_channel|
          room_channel.text_messages.create! message_text: 'This is message 3', message_generator_key: 'a.generator.key'
          room_channel.channel_groups.create!( text_group: TextGroup.new )
        end

        business.admins << manager
      end
    end

    test 'listing all the channels' do
      get "/api/#{business.id}/channels", as: :json, headers: authentication_header( manager )
      assert_equal 200, response.status
      json_response = JSON.parse( response.body )

      assert_equal business.channels.map(&:id).to_set, json_response['channels'].map{|hsh| hsh['id'] }.to_set
      business.channels.map(&:text_messages).flatten.map(&:message_text).each do |text|
        assert json_response['messages'].find{|hsh| hsh['message_text'].match(text) }
      end

      assert_equal business.channels.find_all{|channel| channel.topic == ::Channel::ROOM_TOPIC }.map(&:channel_groups).flatten.map(&:id), json_response['permanent_channel_groups'].map{|h| h['id']}
    end

    test 'listing channels that have been updated after a time' do
      last_updated_at = Time.now - 10.minute
      old_channels = business.channels.first(2).each{|channel| channel.update_attribute(:updated_at, last_updated_at - 1.second)}

      get "/api/#{business.id}/channels?last_updated_at=#{last_updated_at.to_i}", as: :json, headers: authentication_header( manager )
      assert_equal 200, response.status
      json_response = JSON.parse( response.body )

      old_channels.each do |channel|
        assert !json_response['channels'].find{|hsh| hsh['id'] == channel.id }
      end

      (business.channels - old_channels).each do |channel|
        assert json_response['channels'].find{|hsh| hsh['id'] == channel.id }
      end

      updated_at_response = json_response.dig('cache_info', 'channels_updated_at')

      assert_equal Time.at(updated_at_response), business.channels.last.updated_at
    end
  end
end
