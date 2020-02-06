require 'test_helper'
require 'controllers/data_api/controller_test_helper.rb'

module DataApi
  class GroupsControllerTest < ActionDispatch::IntegrationTest
    include ControllerTestHelper

    def manager
      @manager ||= Person.create! name: 'manager'
    end

    def business
      @business ||= create_business
    end

    def create_business(business = Business.new, people: 4.times.map{ Person.new name: Faker::Name.name  })
      business.save! if business.new_record?
      root_channel = business.channels.create!( topic: ::Channel::ROOT_TOPIC, started_by_person: manager )
      root_channel.people << [manager, people].flatten.uniq
      business.admins << manager
      business
    end

    def people
      business.root_channel.people
    end

    test 'create a new group' do
      post "/api/#{business.id}/groups", params: { name: 'A new group', added_contact_ids: people.first(2).map(&:id) }, as: :json, headers: authentication_header( manager )
      assert_equal 201, response.status
      json_response = JSON.parse( response.body )

      new_group_id = json_response.dig( 'text_groups', 0, 'id' )
      assert_equal 'A new group', TextGroup.find(new_group_id).name
      assert_equal 2, json_response['text_group_people'].length
      json_response['text_group_people'].each do |hsh|
        assert TextGroupPerson.find(hsh['id'])
      end

      assert_equal people.first(2).map(&:id), json_response['text_group_people'].map{|h| h['person_id'] }
      assert json_response['text_group_people'].all?{|h| h['text_group_id'] == new_group_id }

      assert_equal [], json_response.dig('permanent_channel_groups')

    end

    test 'create a new group as a permanent channel' do
      post "/api/#{business.id}/groups", params: { set_permanent: true, name: 'A new permanent group', added_contact_ids: people.first(2).map(&:id) }, as: :json, headers: authentication_header( manager )
      assert_equal 201, response.status
      json_response = JSON.parse( response.body )

      new_group_id = json_response.dig( 'text_groups', 0, 'id' )
      assert_equal 'A new permanent group', TextGroup.find(new_group_id).name
      assert_equal 2, json_response['text_group_people'].length
      json_response['text_group_people'].each do |hsh|
        assert TextGroupPerson.find(hsh['id'])
      end

      assert_equal people.first(2).map(&:id), json_response['text_group_people'].map{|h| h['person_id'] }
      assert json_response['text_group_people'].all?{|h| h['text_group_id'] == new_group_id }

      assert json_response.dig('permanent_channel_groups', -1, 'id').present?
      new_channel_id = json_response.dig('permanent_channel_groups', -1, 'channel_id')

      permanent_channel = json_response['channels'].find{|channel| channel['id'] == new_channel_id }
      assert permanent_channel.present?
      assert_equal business.id, permanent_channel['business_id']
      assert_equal 'room', permanent_channel['topic']
      assert_equal manager.id, permanent_channel['started_by_person_id']
    end

    test 'modify a group' do
      existing_text_group = TextGroup.create! business: business, name: 'Existing group', people: people.first(2)
      put "/api/#{business.id}/groups/#{existing_text_group.id}", params: { name: 'Existing group (altered)', added_contact_ids: [ people[2].id ], deleted_contact_ids: [ people[0].id ]  }, as: :json, headers: authentication_header( manager )
      assert_equal 202, response.status

      json_response = JSON.parse( response.body )
      assert_equal existing_text_group.id, json_response.dig( 'text_groups', 0, 'id')
      assert_equal 'Existing group (altered)', json_response.dig( 'text_groups', 0, 'name')

      assert_equal 2, json_response['text_group_people'].length
      assert_equal people[1..2].map(&:id), json_response['text_group_people'].map{|h| h['person_id'] }
      assert json_response['text_group_people'].all?{|h| h['text_group_id'] == existing_text_group.id }

      existing_text_group.reload
      assert_equal 'Existing group (altered)', existing_text_group.name
      assert_equal existing_text_group.people.map(&:id), people[1..2].map(&:id)
    end

    test 'modify a group and make it permanent' do
      existing_text_group = TextGroup.create! business: business, name: 'Existing group', people: people.first(2)
      put "/api/#{business.id}/groups/#{existing_text_group.id}", params: { name: 'Existing group (altered)', added_contact_ids: [ people[2].id ], deleted_contact_ids: [ people[0].id ], set_permanent: true  }, as: :json, headers: authentication_header( manager )
      assert_equal 202, response.status

      json_response = JSON.parse( response.body )

      assert json_response.dig('permanent_channel_groups', -1, 'id').present?
      new_channel_id = json_response.dig('permanent_channel_groups', -1, 'channel_id')

      permanent_channel = json_response['channels'].find{|channel| channel['id'] == new_channel_id }
      assert permanent_channel.present?
      assert_equal business.id, permanent_channel['business_id']
      assert_equal 'room', permanent_channel['topic']
      assert_equal manager.id, permanent_channel['started_by_person_id']

    end

    test 'modify a group and make it transient' do
      existing_text_group = TextGroup.create! business: business, name: 'Existing group', people: people.first(2)
      Channel.create_group_channel( business, existing_text_group, started_by: manager )
      assert existing_text_group.permanent_channels.exists?
      put "/api/#{business.id}/groups/#{existing_text_group.id}", params: { name: 'Existing group (altered)', added_contact_ids: [ people[2].id ], deleted_contact_ids: [ people[0].id ], set_permanent: false  }, as: :json, headers: authentication_header( manager )
      assert_equal 202, response.status

      json_response = JSON.parse( response.body )
      assert_equal [], json_response.dig('permanent_channel_groups')
    end

    test 'delete a group' do
      existing_text_group = TextGroup.create! business: business, name: 'Existing group', people: people.first(2)
      delete "/api/#{business.id}/groups/#{existing_text_group.id}", as: :json, headers: authentication_header( manager )
      assert_equal 202, response.status

      json_response = JSON.parse( response.body )
      assert_equal existing_text_group.id, json_response['id']
      assert !TextGroup.where( id: existing_text_group.id ).exists?
    end

    test 'sequesters data when creating a record' do
      other_business = create_business( people: people )
      other_business_group = TextGroup.create! name: 'other business group', business: other_business
      other_business_group.people << people

      post "/api/#{business.id}/groups", params: { name: 'A new group', added_contact_ids: people.first(2).map(&:id) }, as: :json, headers: authentication_header( manager )
      json_response = JSON.parse( response.body )

      assert json_response['text_group_people'].find_all{|h| !business.text_groups.reload.map(&:id).include?(h['text_group_id']) }.blank?
    end

    test 'sequesters data when updating a record' do
      other_business = create_business( people: people )
      other_business_group = TextGroup.create! name: 'other business group', business: other_business
      other_business_group.people << people

      existing_text_group = TextGroup.create! business: business, name: 'Existing group', people: people.first(2)
      put "/api/#{business.id}/groups/#{existing_text_group.id}", params: { name: 'Existing group (altered)', added_contact_ids: [ people[2].id ], deleted_contact_ids: [ people[0].id ]  }, as: :json, headers: authentication_header( manager )

      json_response = JSON.parse( response.body )

      assert json_response['text_group_people'].find_all{|h| !business.text_groups.reload.map(&:id).include?(h['text_group_id']) }.blank?
    end
  end
end
