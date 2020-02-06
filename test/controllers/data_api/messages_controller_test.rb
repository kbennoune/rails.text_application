require 'test_helper'
require 'controllers/data_api/controller_test_helper.rb'

module DataApi
  class MessagesControllerTest < ActionDispatch::IntegrationTest
    include ControllerTestHelper

    def business
      @business ||= Business.create! admins: [ manager ]
    end

    def root_channel
      @root_channel ||= Channel.create!( topic: ::Channel::ROOT_TOPIC, business: business, started_by_person: manager ).tap{|channel| channel.people << manager }
    end

    def manager
      @manager ||= Person.create! name: 'manager'
    end

    def receiver
      @receiver ||= Person.create!( name: 'a receiver', channels: [root_channel] )
    end

    test 'creating a message' do
      message_text = 'This is a message'

      post "/api/#{business.id}/messages", params: { message_text: message_text, people_ids: [ receiver.id ] }, as: :json, headers: authentication_header( manager )
      assert_equal 200, response.status
      assert_equal 'application/json', response.content_type
      json_response = JSON.parse( response.body )
      saved_sender_message = TextMessage.where( "message_generator_keys LIKE '%#{message_text}%'" ).where("message_generator_keys LIKE '%success.sender%'").last
      saved_recipient_message = TextMessage.where( "message_generator_keys LIKE '%#{message_text}%'" ).where("message_generator_keys LIKE '%success.recipient%'").last
      assert saved_sender_message.present?
      assert_equal saved_sender_message.id, json_response['messages'].find{|msg| msg['message_text'].match(message_text) }.try(:[],'id')

      assert json_response['channels'].find{|channel| channel['id'] == saved_sender_message.channel_id }

      expected_recipients = [ manager, receiver ].flatten.map(&:id).to_set
      assert_equal expected_recipients, actual_recipients( saved_sender_message.channel )
    end

    test 'creating a new channel for the message' do
      message_text = 'This is a message'

      post "/api/#{business.id}/messages", params: { message_text: message_text, people_ids: [ receiver.id ] }, as: :json, headers: authentication_header( manager )
      json_response = JSON.parse( response.body )

      saved_sender_channel_ids = json_response['messages'].map{|message| message['channel_id']}.uniq
      assert_equal 1, saved_sender_channel_ids.length
      saved_sender_channel = Channel.find( saved_sender_channel_ids[0] )

      assert_equal ::Channel::CHAT_TOPIC, saved_sender_channel.topic
    end


    def actual_recipients( channel )
      channel.people.map(&:id).to_set
    end

    def text_group_1_people
      @text_group_1_people ||= [
        Person.create!( name: 'TG1 person1', channels: [ root_channel ] )
      ]
    end

    def text_group_2_people
      @text_group_2_people ||= [
        Person.create!( name: 'TG2 person1', channels: [ root_channel ] ),
        Person.create!( name: 'TG2 person2', channels: [ root_channel ] )
      ]
    end

    def text_groups
      @text_groups ||= [
        TextGroup.create!( business: business, people: text_group_1_people),
        TextGroup.create!( business: business, people: text_group_2_people)
      ]
    end

    test 'creating a message from text groups' do
      message_text = 'This is another message'

      post "/api/#{business.id}/messages", params: { message_text: message_text, text_group_ids: text_groups.map(&:id), people_ids: [ receiver.id ] }, as: :json, headers: authentication_header( manager )
      assert_equal 200, response.status
      assert_equal 'application/json', response.content_type
      json_response = JSON.parse( response.body )
      json_response = JSON.parse( response.body )
      saved_sender_message = TextMessage.where( "message_generator_keys LIKE '%#{message_text}%'" ).where("message_generator_keys LIKE '%success.sender%'").last
      saved_recipient_message = TextMessage.where( "message_generator_keys LIKE '%#{message_text}%'" ).where("message_generator_keys LIKE '%success.recipient%'").last
      assert saved_sender_message.present?
      assert_equal saved_sender_message.id, json_response['messages'].find{|msg| msg['message_text'].match(message_text) }.try(:[],'id')

      assert json_response['channels'].find{|channel| channel['id'] == saved_sender_message.channel_id }

      expected_recipients = [ text_groups.map(&:people), manager, receiver ].flatten.map(&:id).to_set
      assert_equal expected_recipients, actual_recipients( saved_sender_message.channel )

    end

    test 'creating a message with the same receivers as an existing channel' do
      root_channel

      existing_channel = ::Channel.create!(
        topic: ::Channel::CHAT_TOPIC, business_id: business.id,
        started_by_person: manager, text_groups: [text_groups[0]]
      )

      existing_channel.people << text_groups[0].people
      existing_channel.people << manager

      message_text = 'This is another message for an existing channel'
      post "/api/#{business.id}/messages", params: { message_text: message_text, text_group_ids: [text_groups[0].id], people_ids: [] }, as: :json, headers: authentication_header( manager )

      json_response = JSON.parse( response.body )
      new_channel_id = json_response.dig('channels', 0, 'id')
      assert new_channel_id

      assert_equal existing_channel.id, new_channel_id
    end

  end
end
