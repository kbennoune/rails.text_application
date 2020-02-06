require 'test_helper'

module ApplicationPhoneNumberTestHelper
  def setup_channel_people
    @channel_people_arr = people.map do |_,person|
      ChannelPerson.create!(
        person: person, channel: channels[:root],
        application_phone_number: application_phone_numbers[0]
      )
    end
  end

  def channel_people
    ChannelPerson.all.inject({}){|acc, cp| acc[[cp.person_id, cp.channel_id]] = cp; acc }
  end

  def setup_application_phone_numbers
    application_phone_numbers
  end

  def application_phone_numbers
    @application_phone_numbers ||= 4.times.map do |n|
      ApplicationPhoneNumber.create! number: PhoneNumber.new("1313288000#{n}")
    end
  end

  def business
    @business ||= Business.create! facebook_place: FacebookPlace.new
  end

  def people
    @people ||= [
      ::Person.new( name: 'Jaime Manager', mobile: '5555551000'),
      ::Person.new( name: 'Terry Chef', mobile: '5555551001'),
      ::Person.new( name: 'Jesse Server', mobile: '5555551002'),
      ::Person.new( name: 'Taylor Server', mobile: '5555551003'),
      ::Person.new( name: 'Francis Dishwasher', mobile: '5555551004')
    ].inject({}){|acc, p| acc[p.name] = p; acc}
  end

  def channels
    @channels ||= {
      root: ::Channel.create!(business: business, topic: ::Channel::ROOT_TOPIC),
      room: ::Channel.create!(business: business, topic: ::Channel::ROOM_TOPIC),
      chat1: ::Channel.create!(business: business, topic: ::Channel::CHAT_TOPIC),
      chat2: ::Channel.create!(business: business, topic: ::Channel::CHAT_TOPIC),
      chat3: ::Channel.create!(business: business, topic: ::Channel::CHAT_TOPIC),
      chat4: ::Channel.create!(business: business, topic: ::Channel::CHAT_TOPIC)
    }
  end

  def fill_available_numbers(person)
    (1..(application_phone_numbers.size - 1)).each do |n|
      channel = channels[:"chat#{n}"]
      ChannelPerson.new( person: person, channel: channel).tap do |cp|
        cp.application_phone_number = ApplicationPhoneNumber.next_available(person, channel, cp)
        cp.save!
      end
    end
  end
end

class ApplicationPhoneNumberTest < ActiveSupport::TestCase
  include ApplicationPhoneNumberTestHelper

  def setup
    super

    ApplicationPhoneNumber.delete_all
    setup_application_phone_numbers
    setup_channel_people
  end

  test 'picks the next unused number for a user' do
    next_available_number = ApplicationPhoneNumber.next_available(
      people['Taylor Server'], channels[:chat1],
      ChannelPerson.new( person: people['Taylor Server'], channel: channels[:chat1] )
    )

    assert_kind_of ApplicationPhoneNumber, next_available_number
    root_channel_phone_number = channel_people[ [people['Taylor Server'].id, channels[:root].id] ].application_phone_number
    assert next_available_number != root_channel_phone_number
  end

  test 'picks the first number for a root topic' do
    new_person = Person.create! name: 'new user', mobile: '1234567890'
    link_record = ChannelPerson.new person: new_person, channel: channels[:root]

    next_available_number = ApplicationPhoneNumber.next_available( new_person, channels[:root], link_record )
    assert_equal ApplicationPhoneNumber.first.id, next_available_number.id
  end

  test 'will pick the same number for different users' do
    person1 = people['Jaime Manager']#::Person.new( name: 'new person 1', mobile: '5555555000')
    person2 = people['Terry Chef']#::Person.new( name: 'new person 2', mobile: '5555555001')
    channel = channels[:chat1]

    link_record1 = ChannelPerson.create!( person: person1, channel: channel)
    root_phone_number = link_record1.application_phone_number

    link_record2 = ChannelPerson.new( person: person1, channel: channel)
    next_available_number = ApplicationPhoneNumber.next_available(person2, channel, link_record2)

    assert_equal root_phone_number.id, next_available_number.id
  end

  test 'continues to pick unused numbers' do
    person = people['Taylor Server']

    channel_links = (1..3).map do |n|
      channel = channels[:"chat#{n}"]
      ChannelPerson.new( person: person, channel: channel).tap do |cp|
        cp.application_phone_number = ApplicationPhoneNumber.next_available(person, channel, cp)
        cp.save!
      end
    end

    assert_equal 3, channel_links.map(&:application_phone_number_id).uniq.size
  end

  test 'adds an error to the join record if the numbers have been assigned in the last 4 hours' do
    person  = people['Taylor Server']
    fill_available_numbers(person)

    channel = channels[:chat4]

    link_record = ChannelPerson.new( person: person, channel: channel)
    next_available_number = ApplicationPhoneNumber.next_available(person, channel, link_record)

    assert next_available_number.nil?
    assert link_record.errors[:application_phone_number_id].present?
  end

  test 'after using all of the unused numbers it will use the oldest unused number older than 4 hours' do
    person  = people['Taylor Server']
    fill_available_numbers(person)
    channel_people[ [person.id, channels[:chat1].id] ].update(created_at: Time.now - 4.hours)

    channel = channels[:chat4]

    link_record = ChannelPerson.new( person: person, channel: channel)
    next_available_number = ApplicationPhoneNumber.next_available(person, channel, link_record)

    assert_equal channel_people[ [person.id, channels[:chat1].id] ].application_phone_number, next_available_number
  end

  test 'it will not reassign the root channel' do
    person  = people['Taylor Server']
    channel = channels[:root]
    fill_available_numbers(person)
    channel_people[ [person.id, channel.id] ].update(created_at: Time.now - 4.hours)
    link_record = ChannelPerson.new( person: person, channel: channel)
    next_available_number = ApplicationPhoneNumber.next_available(person, channel, link_record)

    assert next_available_number.nil?
    assert link_record.errors[:application_phone_number_id].present?

    channel_people[ [person.id, channels[:chat1].id] ].update(created_at: Time.now - 4.hours)
    next_available_number = ApplicationPhoneNumber.next_available(person, channel, link_record)

    assert_equal channel_people[ [person.id, channels[:chat1].id] ].application_phone_number, next_available_number
  end

  test 'it will not reassign the room channel' do
    person  = people['Taylor Server']
    room_channel = channels[:room]

    fill_available_numbers(person)

    additional_number = ApplicationPhoneNumber.create! number: PhoneNumber.new("13132880010")
    room_channel_person = ChannelPerson.create!( person: person, application_phone_number: additional_number, channel: room_channel, created_at: Time.now - 4.hours )

    new_channel = ::Channel.create! business: business, topic: ::Channel::CHAT_TOPIC

    link_record = ChannelPerson.new( person: person, channel: new_channel )
    next_available_number = ApplicationPhoneNumber.next_available(person, new_channel, link_record)

    assert next_available_number.nil?
    assert link_record.errors[:application_phone_number_id].present?

    channel_people[ [person.id, channels[:chat1].id] ].update(created_at: Time.now - 4.hours)
    next_available_number = ApplicationPhoneNumber.next_available(person, new_channel, link_record)

    assert_equal channel_people[ [person.id, channels[:chat1].id] ].application_phone_number, next_available_number
  end

  test 'it will not reassign active channels having recent texts' do
    person  = people['Taylor Server']

    fill_available_numbers(person)
    channel_people[ [person.id, channels[:chat1].id] ].update(created_at: Time.now - 4.hours)
    text_message = TextMessage.create! channel: channels[:chat1]
    channel = channels[:chat4]

    link_record = ChannelPerson.new( person: person, channel: channel)
    next_available_number = ApplicationPhoneNumber.next_available(person, channel, link_record)

    assert next_available_number.nil?
    assert link_record.errors[:application_phone_number_id].present?

    channel2_text = TextMessage.create! channel: channels[:chat2], created_at: Time.now - 5.hours
    channel_people[ [person.id, channels[:chat2].id] ].update(created_at: Time.now - 6.hours)

    next_available_number = ApplicationPhoneNumber.next_available(person, channel, link_record)
    assert_equal channel_people[ [person.id, channels[:chat2].id] ].application_phone_number, next_available_number
  end
end

class ApplicationPhoneNumberNextAvailableTest < ActiveSupport::TestCase

  include ApplicationPhoneNumberTestHelper

  test "it will not reassign a number that's been used by multiple chat numbers" do
    application_phone_number = application_phone_numbers.first
    person = people['Jaime Manager']

    channel_people = [ ::Channel::CHAT_TOPIC, ::Channel::ROOM_TOPIC, ::Channel::ROOT_TOPIC ].map do |topic|
      ChannelPerson.create!(
        person: person, channel: Channel.new(business: business, topic: topic),
        application_phone_number: application_phone_number, created_at: (Time.now - 1.hour)
      )
    end

    channel_people.each do |channel_person|
      2.times.each{
        TextMessage.create! channel_id: channel_person.channel_id#, created_at: (Time.now - 10.minutes)
      }
    end

    TextMessage.create! channel_id: channel_people[0].channel_id, created_at: (Time.now - 10.minutes)

    refute_includes ApplicationPhoneNumber.next_available_number_query(1.minute, person), application_phone_number
  end

  test 'it will not reassign a number if there is an old channel' do
    application_phone_number = application_phone_numbers.first
    person = people['Jaime Manager']

    channel_people = [ ::Channel::CHAT_TOPIC, ::Channel::ROOM_TOPIC, ::Channel::ROOT_TOPIC ].map do |topic|
      ChannelPerson.create!(
        person: person, channel: Channel.new(business: business, topic: topic),
        application_phone_number: application_phone_number
      )
    end

    channel_people[0].update_attributes( created_at: Time.now - 4.hours )
    TextMessage.create! channel_id: channel_people[0].channel_id, created_at: (Time.now - 10.minutes)
    refute_includes ApplicationPhoneNumber.next_available_number_query(1.minute, person), application_phone_number
  end

end
