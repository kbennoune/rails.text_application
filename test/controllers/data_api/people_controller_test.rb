require 'test_helper'
require 'controllers/data_api/controller_test_helper.rb'

module DataApi
  class PeopleControllerTest < ActionDispatch::IntegrationTest
    include ControllerTestHelper

    def manager
      @manager ||= Person.create! name: 'manager'
    end

    def business
      @business ||= create_business
    end

    def create_business(business=Business.new, people: 4.times.map{ Person.new name: Faker::Name.name  }, group_names: ['Group 1', 'Group 2', 'Group 3'])
      business.save! if business.new_record?

      business.tap do |business|
        root_channel = business.channels.create!( topic: ::Channel::ROOT_TOPIC, started_by_person: manager )
        # root_channel.people << manager
        # Automatically saves people
        root_channel.people << [ manager, people ].flatten.uniq

        group_names.each do |name|
          business.text_groups.create! name: name
        end

        business.admins << manager
      end
    end

    def people
      business.root_channel.people
    end

    def root_channel
      business.root_channel
    end

    test 'create a person' do
      params = {
        name: Faker::Name.name,
        mobile: Faker::PhoneNumber.cell_phone,
        added_text_group_ids: business.text_groups[0..1].map(&:id)
      }
      post "/api/#{business.id}/people", params: params, as: :json, headers: authentication_header( manager )
      assert_equal 201, response.status
      json_response = JSON.parse( response.body )

      new_person_id = json_response.dig( 'people', 0, 'id' )
      assert_equal params[:name], Person.find( new_person_id ).name
      assert_equal 2, json_response.dig( 'text_group_people' ).size

      params[:added_text_group_ids].each do |id|
        join_json = json_response.dig( 'text_group_people' ).find{|json| json['text_group_id'].to_i == id }
        assert_equal new_person_id, join_json['person_id']
      end
    end

    test 'sends a sign up message to new contacts' do
      params = {
        name: Faker::Name.name,
        mobile: Faker::PhoneNumber.cell_phone,
        added_text_group_ids: business.text_groups[0..1].map(&:id)
      }
      post "/api/#{business.id}/people", params: params, as: :json, headers: authentication_header( manager )
      assert_equal 201, response.status
      json_response = JSON.parse( response.body )

      new_person_id = json_response.dig( 'people', 0, 'id' )

      admission_message_translation_key = "channel_topics.person.admission.success"
      admission_message = TextMessage.where( channel: root_channel, to: [PhoneNumber.new(params[:mobile])] ).find{|msg|
        msg.message_generator_keys.find{|h| h['key'] == admission_message_translation_key }
      }

      assert admission_message
      assert admission_message.message_generator_keys.find{|h| h['key'] == admission_message_translation_key && h.dig('values', 'sender') == manager.name }
      assert admission_message.message_generator_keys.find{|h| h['key'] == admission_message_translation_key && h.dig('values', 'business_name') == business.name }

    end

    test 'update a person' do
      params = {
        name: Faker::Name.name,
        mobile: Faker::PhoneNumber.cell_phone,
        added_text_group_ids: [ business.text_groups[2].id ],
        deleted_text_group_ids: [ business.text_groups[0].id ]
      }

      person = Person.create! name: Faker::Name.name, mobile: Faker::PhoneNumber.cell_phone, channels: [root_channel], text_groups: business.text_groups[0..1]
      put "/api/#{business.id}/people/#{person.id}", params: params, as: :json, headers: authentication_header( manager )
      assert_equal 202, response.status
      json_response = JSON.parse( response.body )

      assert_equal params[:name], json_response.dig('people', 0, 'name')
      assert_equal PhoneNumber.new(params[:mobile]), PhoneNumber.new(json_response.dig('people', 0, 'mobile'))
      assert business.text_groups.all?{|tg| TextGroup.where( id: tg.id ).exists? }
      assert_equal 2, json_response['text_group_people'].size
      business.text_groups[1..2].each do |tg|
        assert json_response['text_group_people'].find{|hsh| hsh['text_group_id'].to_i == tg.id}
      end

      person.reload
      assert_equal business.text_groups[1..2], person.text_groups
      assert_equal params[:name], person.name
    end

    test 'update a person with null fields' do
      params = {
        name: '',
        mobile: nil,
        added_text_group_ids: [ business.text_groups[2].id ],
        deleted_text_group_ids: [ business.text_groups[0].id ]
      }

      cell_phone_number = Faker::PhoneNumber.cell_phone

      person = Person.create! name: Faker::Name.name, mobile: cell_phone_number, channels: [root_channel], text_groups: business.text_groups[0..1]
      put "/api/#{business.id}/people/#{person.id}", params: params, as: :json, headers: authentication_header( manager )
      assert_equal 202, response.status
      json_response = JSON.parse( response.body )

      assert_equal '', json_response.dig('people', 0, 'name')
      assert_equal person.mobile, json_response.dig('people', 0, 'mobile')
    end

    test 'delete a person (remove from business)' do
      person = people.last
      delete "/api/#{business.id}/people/#{person.id}", as: :json, headers: authentication_header( manager )
      assert_equal 202, response.status

      json_response = JSON.parse( response.body )
      assert_equal person.id, json_response['id']
      assert !root_channel.people.where( id: person.id ).exists?
    end

    test 'listing people' do
      get "/api/#{business.id}/people", as: :json, headers: authentication_header( manager )
      json_response = JSON.parse( response.body )
      people.each do |person|
        assert json_response['people'].find{|hsh| hsh['id'] == person.id }
      end

      business.text_groups.each do |text_group|
        assert json_response['text_groups'].find{|hsh| hsh['id'] == text_group.id }
      end

      business.channels.each do |channel|
        assert json_response['channels'].find{|hsh| hsh['id'] == channel.id }
      end
    end

    test 'listing people with last_updated_at' do
      last_updated_at = Time.now - 10.minute

      old_people = people.first(2).each{|person| person.update_attribute(:updated_at, last_updated_at - 1.second)}
      old_channels = business.channels.first(2).each{|channel| channel.update_attribute(:updated_at, last_updated_at - 1.second)}

      get "/api/#{business.id}/people?last_updated_at=#{last_updated_at.to_i}", as: :json, headers: authentication_header( manager )
      json_response = JSON.parse( response.body )

      (people - old_people).each do |person|
        assert json_response['people'].find{|hsh| hsh['id'] == person.id }
      end

      old_people.each do |person|
        assert !json_response['people'].find{|hsh| hsh['id'] == person.id }
      end

      (business.channels - old_channels).each do |channel|
        assert json_response['channels'].find{|hsh| hsh['id'] == channel.id }
      end

      old_channels.each do |channel|
        assert !json_response['channels'].find{|hsh| hsh['id'] == channel.id }
      end
    end

    test 'data is sequestered between businesses when listing' do
      other_business = create_business(people: [people, Person.new(name: 'Another Manager')])
      business_text_group = business.text_groups[0]
      other_business_text_group = other_business.text_groups.last

      business_text_group.people << people
      other_business_text_group.people << people

      get "/api/#{business.id}/people", as: :json, headers: authentication_header( manager )
      json_response = JSON.parse( response.body )

      assert_empty json_response['text_group_people'].find_all{|hsh| hsh['text_group_id'] != business_text_group.id }
      assert_empty json_response['channels'].find_all{|hsh| !business.channels.map(&:id).include?(hsh['id']) }
      assert_empty json_response['text_groups'].find_all{|hsh| !business.text_groups.map(&:id).include?(hsh['id']) }
      assert_empty json_response['people'].find_all{|hsh| !people.map(&:id).include?(hsh['id']) }
      assert_empty json_response['businesses'].find_all{|hsh| hsh['id'] != business.id }
    end

    test 'data is sequestered between businesses when updating' do
      other_business = create_business(people: [people, Person.new(name: 'Another Manager')])
      other_business_text_group = other_business.text_groups.last
      other_business_text_group.people << people

      params = {
        name: Faker::Name.name,
        mobile: Faker::PhoneNumber.cell_phone,
        added_text_group_ids: [ business.text_groups[2].id ],
      }

      update_person = people.last
      put "/api/#{business.id}/people/#{update_person.id}", params: params, as: :json, headers: authentication_header( manager )
      json_response = JSON.parse( response.body )

      assert_empty json_response['text_group_people'].find_all{|h| !business.text_groups.map(&:id).include?(h['text_group_id']) }
    end

    test 'data is sequestered between businesses when creating' do
      other_business = create_business(people: [people, Person.new(name: 'Another Manager')])
      other_business_text_group = other_business.text_groups.last
      other_business_text_group.people << people

      params = {
        name: Faker::Name.name,
        mobile: Faker::PhoneNumber.cell_phone,
        added_text_group_ids: business.text_groups[0..1].map(&:id)
      }
      post "/api/#{business.id}/people", params: params, as: :json, headers: authentication_header( manager )

      json_response = JSON.parse( response.body )

      assert_empty json_response['text_group_people'].find_all{|h| !business.text_groups.map(&:id).include?(h['text_group_id']) }
    end
  end
end
