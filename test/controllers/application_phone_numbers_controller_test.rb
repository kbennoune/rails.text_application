require 'test_helper'

class ApplicationPhoneNumbersControllerTest < ActionController::TestCase


  def business
    @business ||= Business.create! name: 'Tea Leaf Bakery'
  end

  def root_channel
    @root_channel ||= Channel.new({ business_id: business.id, topic: Channel::ROOT_TOPIC })
  end

  def person
    @person ||= Person.create!( name: 'Contact Name').tap do |person|
      person.channels << root_channel
    end
  end

  test 'getting a contact file for a person and business' do
    get :show, params: {person_id: person.id, business_id: business.id}, format: :vcf
    vcard = VCardigan.parse( response.body )

    assert_equal "Tea Leaf Bakery", vcard.fn.first.values.first
    assert_equal person.channel_people.find{|pc| pc.channel.topic == Channel::ROOT_TOPIC }.channel_phone_number, vcard[:item1].tel.first.values.first
    assert_equal ["type", "text"], vcard[:item1].tel.first.params.first

    item2_phone_number = vcard[:item2].tel.first.values.first
    assert ApplicationPhoneNumber.where( number: item2_phone_number ).first
    assert_equal ["type", "text"], vcard[:item2].tel.first.params.first

    assert_match 'utf-8', response.headers['Content-Type']
    assert_match business.name.downcase, response.headers['Content-Type']
    assert_match 'text/x-vcard', response.headers['Content-Type']
  end

  def room_channels
    @room_channels ||= [
      Channel.create!( business: business, topic: Channel::ROOM_TOPIC, text_groups: text_groups.values_at(0) ),
      Channel.create!( business: business, topic: Channel::ROOM_TOPIC, text_groups: text_groups.values_at(0,1) ),
      Channel.create!( business: business, topic: Channel::ROOM_TOPIC, text_groups: text_groups.values_at(2) )
    ]
  end

  def text_groups
    @text_groups ||= [
      TextGroup.create!( name: 'group1', people: [ person], business: business ),
      TextGroup.create!( name: 'group2', people: [ person], business: business ),
      TextGroup.create!( name: 'group3', business: business )
    ]
  end

  def setup
    super
    room_channels
  end

  test 'contact file for chats' do
    Sidekiq::Worker.drain_all
    get :show, params: {person_id: person.id, business_id: business.id}, format: :vcf
    vcards = response.body.split(/(?<=END:VCARD)\n/).map{|vcard| VCardigan.parse( vcard ) }

    puts response.body

    # assert_equal person.channel_people.find{|cp| cp.channel == room_channels[2] }.channel_phone_number, vcards[0][:item2].tel.first.values
    # assert_match (), vcards[0][:item3].tel.first.values

    assert_match /\(\d{3}\) \d{3}-\d{4}/, vcards[0][:item2].tel.first.values.first
    assert_match /\(\d{3}\) \d{3}-\d{4}/, vcards[0][:item3].tel.first.values.first

    assert_match "Chat", vcards[0][:item2].send(:"x-ablabel").first.value
    assert_match "Chat", vcards[0][:item3].send(:"x-ablabel").first.value

    assert_equal person.channel_people.find{|cp| cp.channel == room_channels[0] }.channel_phone_number, vcards[1][:item1].tel.first.values
    assert_match "Group1", vcards[1].fullname.first.value
    assert_equal person.channel_people.find{|cp| cp.channel == room_channels[1] }.channel_phone_number, vcards[2][:item1].tel.first.values

    assert_match "Group1", vcards[2].fullname.first.value
    assert_match "Group2", vcards[2].fullname.first.value

    assert_match "💬 Group1", vcards[1][:item1].send(:'X-ABLabel').first.value
    assert_match "💬 Group1 and Group2", vcards[2][:item1].send(:'X-ABLabel').first.value

  end
end
